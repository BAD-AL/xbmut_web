import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:xbox_memory_unit_tool/xbox_memory_unit_tool.dart';

void main() {
  WebXbmutApp().init();
}

class WebXbmutApp {
  XboxMemoryUnit? _mu;
  String? _fileName;

  // --- UI Elements ---
  late final web.HTMLDivElement _welcomeView;
  late final web.HTMLDivElement _detailView;
  late final web.HTMLDivElement _treeContainer;
  late final web.HTMLDivElement _helpOverlay;
  late final web.HTMLInputElement _fileInput;
  late final web.HTMLDivElement _dropzone;
  late final web.HTMLDivElement _muInfo;

  // Detail view elements
  late final web.HTMLElement _viewGame;
  late final web.HTMLElement _viewSave;
  late final web.HTMLImageElement _viewIcon;
  late final web.HTMLElement _viewId;
  late final web.HTMLElement _viewSize;
  late final web.HTMLElement _viewDate;

  void init() {
    _welcomeView = web.document.querySelector('#welcome-view') as web.HTMLDivElement;
    _detailView = web.document.querySelector('#detail-view') as web.HTMLDivElement;
    _treeContainer = web.document.querySelector('.tree-container') as web.HTMLDivElement;
    _helpOverlay = web.document.querySelector('#help-overlay') as web.HTMLDivElement;
    _fileInput = web.document.querySelector('#file-input') as web.HTMLInputElement;
    _dropzone = web.document.querySelector('.dropzone') as web.HTMLDivElement;
    _muInfo = web.document.querySelector('.mu-info') as web.HTMLDivElement;

    _viewGame = web.document.querySelector('#view-game') as web.HTMLElement;
    _viewSave = web.document.querySelector('#view-save') as web.HTMLElement;
    _viewIcon = web.document.querySelector('#view-icon') as web.HTMLImageElement;
    _viewId = web.document.querySelector('#view-id') as web.HTMLElement;
    _viewSize = web.document.querySelector('#view-size') as web.HTMLElement;
    _viewDate = web.document.querySelector('#view-date') as web.HTMLElement;

    _setupEventListeners();
    _addCreateNewButton();
  }

  void _setupEventListeners() {
    // Dropzone events
    _dropzone.addEventListener('dragover', (web.DragEvent e) {
      e.preventDefault();
      _dropzone.style.borderColor = 'var(--accent-green)';
    }.toJS);

    _dropzone.addEventListener('dragleave', (web.DragEvent e) {
      _dropzone.style.borderColor = 'var(--border-color)';
    }.toJS);

    _dropzone.addEventListener('drop', (web.DragEvent e) {
      e.preventDefault();
      _dropzone.style.borderColor = 'var(--border-color)';
      final dt = e.dataTransfer;
      if (dt != null && dt.files.length > 0) {
        _handleFile(dt.files.item(0)!);
      }
    }.toJS);

    // File input events
    _fileInput.onchange = (web.Event e) {
      if (_fileInput.files != null && _fileInput.files!.length > 0) {
        _handleFile(_fileInput.files!.item(0)!);
      }
    }.toJS;

    // Header buttons
    web.document.querySelector('.btn-primary')?.addEventListener('click', (web.MouseEvent e) {
      _exportCard();
    }.toJS);

    web.document.querySelector('.help-icon-btn')?.addEventListener('click', (web.MouseEvent e) {
      _toggleHelp(true);
    }.toJS);

    _helpOverlay.addEventListener('click', (web.MouseEvent e) {
      _toggleHelp(false);
    }.toJS);

    _helpOverlay.querySelector('.help-card')?.addEventListener('click', (web.MouseEvent e) {
      e.stopPropagation();
    }.toJS);

    _helpOverlay.querySelector('.btn')?.addEventListener('click', (web.MouseEvent e) {
      _toggleHelp(false);
    }.toJS);

    _dropzone.addEventListener('click', (web.MouseEvent e) {
      _fileInput.click();
    }.toJS);

    // Detail view buttons
    _detailView.querySelector('.btn-danger')?.addEventListener('click', (web.MouseEvent e) {
      _deleteSelected();
    }.toJS);

    _detailView.querySelector('.btn:not(.btn-danger)')?.addEventListener('click', (web.MouseEvent e) {
      _exportSelected();
    }.toJS);

    _detailView.querySelectorAll('.btn').item(2)?.addEventListener('click', (web.MouseEvent e) {
      _showWelcome();
    }.toJS);

    // Global drag-and-drop for import
    web.document.body?.addEventListener('dragover', (web.DragEvent e) {
      e.preventDefault();
    }.toJS);

    web.document.body?.addEventListener('drop', (web.DragEvent e) {
      if (_mu != null) {
        e.preventDefault();
        final dt = e.dataTransfer;
        if (dt != null && dt.files.length > 0) {
          _handleImport(dt.files.item(0)!);
        }
      }
    }.toJS);
  }

  void _addCreateNewButton() {
    final btn = web.document.createElement('button') as web.HTMLButtonElement;
    btn.className = 'btn btn-subtle';
    btn.style.marginTop = '10px';
    btn.textContent = 'Create New Memory Unit';
    btn.onclick = (web.Event e) {
      _createNewMU();
    }.toJS;
    _dropzone.appendChild(btn);
  }

  void _toggleHelp(bool show) {
    _helpOverlay.style.display = show ? 'flex' : 'none';
  }

  Future<void> _handleFile(web.File file) async {
    final reader = web.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;
    
    final bytes = (reader.result as JSArrayBuffer).toDart.asUint8List();
    
    if (file.name.toLowerCase().endsWith('.zip')) {
      if (_mu == null) {
        web.window.alert('Please load a Memory Unit (.bin) first before importing a .zip save.');
        return;
      }
      _importZip(bytes);
    } else {
      _loadMU(bytes, file.name);
    }
  }

  Future<void> _handleImport(web.File file) async {
     if (!file.name.toLowerCase().endsWith('.zip')) return;
     
     final reader = web.FileReader();
     reader.readAsArrayBuffer(file);
     await reader.onLoadEnd.first;
     final bytes = (reader.result as JSArrayBuffer).toDart.asUint8List();
     _importZip(bytes);
  }

  void _loadMU(Uint8List bytes, String name) {
    try {
      _mu = XboxMemoryUnit.fromBytes(bytes);
      _fileName = name;
      _updateUI();
    } catch (e) {
      web.window.alert('Error loading Memory Unit: $e');
    }
  }

  void _createNewMU() {
    try {
      _mu = XboxMemoryUnit.format();
      _fileName = 'new_card.bin';
      _updateUI();
    } catch (e) {
      web.window.alert('Error creating Memory Unit: $e');
    }
  }

  void _importZip(Uint8List zipBytes) {
    if (_mu == null) return;
    try {
      _mu!.importZip(zipBytes);
      _updateUI();
    } catch (e) {
      web.window.alert('Error importing ZIP: $e');
    }
  }

  void _updateUI() {
    if (_mu == null) return;

    // Update Header
    final infoSpans = _muInfo.querySelectorAll('span');
    if (infoSpans.length >= 3) {
      (infoSpans.item(0) as web.HTMLElement).innerHTML = '<strong>Device:</strong> $_fileName'.toJS;
      (infoSpans.item(1) as web.HTMLElement).innerHTML = '<strong>Capacity:</strong> ${(_mu!.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB'.toJS;
      (infoSpans.item(2) as web.HTMLElement).innerHTML = '<strong>Used:</strong> ${((_mu!.totalBytes - _mu!.freeBytes) / 1024 / 1024).toStringAsFixed(1)} MB'.toJS;
    }

    _renderTree();
    _showWelcome();
  }

  void _renderTree() {
    _treeContainer.innerHTML = ''.toJS;
    if (_mu == null) return;

    for (final title in _mu!.titles) {
      final details = web.document.createElement('details') as web.HTMLDetailsElement;
      details.className = 'tree-item';
      
      final summary = web.document.createElement('summary') as web.HTMLElement;
      summary.innerHTML = '<img src="icons/folder.svg" class="xbox-icon" alt="Folder"> ${title.name}'.toJS;
      details.appendChild(summary);

      final saveList = web.document.createElement('div') as web.HTMLDivElement;
      saveList.className = 'save-list';
      
      for (final save in title.saves) {
        final saveItem = web.document.createElement('div') as web.HTMLDivElement;
        saveItem.className = 'save-item';
        saveItem.textContent = save.name;
        saveItem.onclick = (web.Event e) {
          _showDetail(title.name, save.name);
        }.toJS;
        saveList.appendChild(saveItem);
      }
      
      details.appendChild(saveList);
      _treeContainer.appendChild(details);
    }
  }

  void _showWelcome() {
    _welcomeView.style.display = 'block';
    _detailView.style.display = 'none';
  }

  void _showDetail(String titleName, String saveName) {
    if (_mu == null) return;
    final title = _mu!.titles.firstWhere((t) => t.name == titleName);
    final save = title.saves.firstWhere((s) => s.name == saveName);

    _welcomeView.style.display = 'none';
    _detailView.style.display = 'block';

    _viewGame.textContent = title.name;
    _viewSave.textContent = save.name;
    _viewId.textContent = title.id;
    _viewSize.textContent = '${(save.size / 1024).toStringAsFixed(0)} KB';
    _viewDate.textContent = _formatDate(save.modifiedAt);

    // Set icon if available (placeholder for now as library might not extract icons to web easily yet)
    _viewIcon.src = 'https://via.placeholder.com/128x128/1a1a1a/107c10?text=SAVE';

    _detailView.classList.remove('fade-in');
    // Trigger reflow
    _detailView.offsetWidth;
    _detailView.classList.add('fade-in');
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _deleteSelected() {
    if (_mu == null) return;
    final path = '${_viewGame.textContent}/${_viewSave.textContent}';
    if (web.window.confirm('Are you sure you want to delete "$path"?')) {
      try {
        _mu!.delete(path);
        _updateUI();
        _showWelcome();
      } catch (e) {
        web.window.alert('Error deleting: $e');
      }
    }
  }

  void _exportSelected() {
    if (_mu == null) return;
    final path = '${_viewGame.textContent}/${_viewSave.textContent}';
    try {
      final bytes = _mu!.export(path);
      _downloadFile(bytes, '${_viewSave.textContent}.zip');
    } catch (e) {
      web.window.alert('Error exporting save: $e');
    }
  }

  void _exportCard() {
    if (_mu == null) return;
    try {
      _downloadFile(_mu!.bytes, _fileName ?? 'card.bin');
    } catch (e) {
      web.window.alert('Error exporting card: $e');
    }
  }

  void _downloadFile(Uint8List bytes, String fileName) {
    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.click();
    web.URL.revokeObjectURL(url);
  }
}
