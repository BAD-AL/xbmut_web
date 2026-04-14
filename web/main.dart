import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:xbox_memory_unit_tool/xbox_memory_unit_tool.dart';

void main() {
  WebXbmutApp().init();
}

class WebXbmutApp {
  static const String version = '1.1.0';
  final List<XboxMemoryUnit?> _mus = [null, null];
  final List<String?> _fileNames = [null, null];
  int _activeSlot = 0;

  XboxMemoryUnit? get _mu => _mus[_activeSlot];
  String? get _fileName => _fileNames[_activeSlot];

  void _switchSlot(int slot) {
    if (_activeSlot == slot) return;
    _activeSlot = slot;
    _slotABtn.classList.toggle('active', _activeSlot == 0);
    _slotBBtn.classList.toggle('active', _activeSlot == 1);
    _updateUI();
  }

  String _getSlotStats(int slot) {
    final mu = _mus[slot];
    if (mu == null) return '';
    final total = mu.totalBytes / 1024 / 1024;
    final used = (mu.totalBytes - mu.freeBytes) / 1024 / 1024;
    return 'Used ${used.toStringAsFixed(1)}MB/${total.toStringAsFixed(0)}MB';
  }

  // --- UI Elements ---
  late final web.HTMLDivElement _welcomeView;
  late final web.HTMLDivElement _detailView;
  late final web.HTMLDivElement _treeContainer;
  late final web.HTMLDivElement _helpOverlay;
  late final web.HTMLInputElement _fileInput;
  late final web.HTMLDivElement _dropzone;
  late final web.HTMLButtonElement _otherLinksBtn;

  // Slot Tabs
  late final web.HTMLButtonElement _slotABtn;
  late final web.HTMLButtonElement _slotBBtn;
  late final web.HTMLElement _slotAName;
  late final web.HTMLElement _slotBName;
  late final web.HTMLElement _slotAStats;
  late final web.HTMLElement _slotBStats;

  // Alert/Toast elements
  late final web.HTMLDivElement _alertOverlay;
  late final web.HTMLElement _alertTitle;
  late final web.HTMLElement _alertMessage;
  late final web.HTMLButtonElement _alertClose;
  late final web.HTMLDivElement _confirmOverlay;
  late final web.HTMLElement _confirmTitle;
  late final web.HTMLElement _confirmMessage;
  late final web.HTMLButtonElement _confirmYes;
  late final web.HTMLButtonElement _confirmNo;
  late final web.HTMLDivElement _selectionOverlay;
  late final web.HTMLElement _selectionTitle;
  late final web.HTMLDivElement _selectionOptions;
  late final web.HTMLButtonElement _selectionCancel;
  late final web.HTMLDivElement _toast;
  late final web.HTMLElement _toastMessage;

  // Header info elements
  late final web.HTMLElement _infoDevice;
  late final web.HTMLElement _infoCapacity;
  late final web.HTMLElement _infoUsed;

  // Detail view elements
  late final web.HTMLElement _viewGame;
  late final web.HTMLElement _viewSave;
  late final web.HTMLImageElement _viewIcon;
  late final web.HTMLElement _viewId;
  late final web.HTMLElement _viewFolder;
  late final web.HTMLElement _viewSize;
  late final web.HTMLElement _viewDate;

  void init() {
    _welcomeView = web.document.querySelector('#welcome-view') as web.HTMLDivElement;
    _detailView = web.document.querySelector('#detail-view') as web.HTMLDivElement;
    _treeContainer = web.document.querySelector('.tree-container') as web.HTMLDivElement;
    _helpOverlay = web.document.querySelector('#help-overlay') as web.HTMLDivElement;
    _fileInput = web.document.querySelector('#file-input') as web.HTMLInputElement;
    _dropzone = web.document.querySelector('.dropzone') as web.HTMLDivElement;
    _otherLinksBtn = web.document.querySelector('#other-links-btn') as web.HTMLButtonElement;

    _slotABtn = web.document.querySelector('#slot-a-btn') as web.HTMLButtonElement;
    _slotBBtn = web.document.querySelector('#slot-b-btn') as web.HTMLButtonElement;
    _slotAName = web.document.querySelector('#slot-a-name') as web.HTMLElement;
    _slotBName = web.document.querySelector('#slot-b-name') as web.HTMLElement;
    _slotAStats = web.document.querySelector('#slot-a-stats') as web.HTMLElement;
    _slotBStats = web.document.querySelector('#slot-b-stats') as web.HTMLElement;

    _alertOverlay = web.document.querySelector('#alert-overlay') as web.HTMLDivElement;
    _alertTitle = web.document.querySelector('#alert-title') as web.HTMLElement;
    _alertMessage = web.document.querySelector('#alert-message') as web.HTMLElement;
    _alertClose = web.document.querySelector('#alert-close') as web.HTMLButtonElement;

    _confirmOverlay = web.document.querySelector('#confirm-overlay') as web.HTMLDivElement;
    _confirmTitle = web.document.querySelector('#confirm-title') as web.HTMLElement;
    _confirmMessage = web.document.querySelector('#confirm-message') as web.HTMLElement;
    _confirmYes = web.document.querySelector('#confirm-yes') as web.HTMLButtonElement;
    _confirmNo = web.document.querySelector('#confirm-no') as web.HTMLButtonElement;

    _selectionOverlay = web.document.querySelector('#selection-overlay') as web.HTMLDivElement;
    _selectionTitle = web.document.querySelector('#selection-title') as web.HTMLElement;
    _selectionOptions = web.document.querySelector('#selection-options') as web.HTMLDivElement;
    _selectionCancel = web.document.querySelector('#selection-cancel') as web.HTMLButtonElement;

    _toast = web.document.querySelector('#toast') as web.HTMLDivElement;
    _toastMessage = web.document.querySelector('#toast-message') as web.HTMLElement;

    _infoDevice = web.document.querySelector('#info-device') as web.HTMLElement;
    _infoCapacity = web.document.querySelector('#info-capacity') as web.HTMLElement;
    _infoUsed = web.document.querySelector('#info-used') as web.HTMLElement;

    _viewGame = web.document.querySelector('#view-game') as web.HTMLElement;
    _viewSave = web.document.querySelector('#view-save') as web.HTMLElement;
    _viewIcon = web.document.querySelector('#view-icon') as web.HTMLImageElement;
    _viewId = web.document.querySelector('#view-id') as web.HTMLElement;
    _viewFolder = web.document.querySelector('#view-folder') as web.HTMLElement;
    _viewSize = web.document.querySelector('#view-size') as web.HTMLElement;
    _viewDate = web.document.querySelector('#view-date') as web.HTMLElement;

    _helpOverlay.querySelector('h2')?.textContent = 'User Manual (v$version)';

    _setupEventListeners();
    _addCreateNewButton();
    _setupExportAll();
    _startGamepadPolling();
  }

  void _startGamepadPolling() {
    // Poll gamepads at 60fps
    web.window.requestAnimationFrame((JSNumber time) {
      _pollGamepad();
      _startGamepadPolling();
    }.toJS);
  }

  bool _buttonPressed = false;
  DateTime _lastGamepadUpdateTime = DateTime.fromMillisecondsSinceEpoch(0);

  void _pollGamepad() {
    final now = DateTime.now();
    if (now.difference(_lastGamepadUpdateTime).inMilliseconds < 150) return;

    final gamepads = web.window.navigator.getGamepads();
    if (gamepads.length == 0) return;
    
    final gp = gamepads[0];
    if (gp == null) return;

    // Xbox Controller Mapping (Standard)
    // Buttons -> 0: A, 1: B, 12: Up, 13: Down, 14: Left, 15: Right
    // Axes -> 0: Left Stick X (-1 to 1), 1: Left Stick Y (-1 to 1)
    
    bool moved = false;

    // A Button (Select)
    if (gp.buttons[0].pressed) {
      final active = web.document.activeElement as web.HTMLElement?;
      active?.click();
      _lastGamepadUpdateTime = now;
      return;
    }
    
    // B Button (Back)
    if (gp.buttons[1].pressed) {
      _goBack();
      _lastGamepadUpdateTime = now;
      return;
    }

    // LB/RB Navigation (Tab/Shift+Tab)
    if (gp.buttons[4].pressed) { // LB
      _moveFocus(-1);
      _lastGamepadUpdateTime = now;
      return;
    } else if (gp.buttons[5].pressed) { // RB
      _moveFocus(1);
      _lastGamepadUpdateTime = now;
      return;
    }

    // Navigation (D-Pad or Left Stick)
    final axisX = gp.axes[0] as double;
    final axisY = gp.axes[1] as double;

    if (gp.buttons[13].pressed || axisY > 0.5) {
      _moveFocus(1);
      moved = true;
    } else if (gp.buttons[12].pressed || axisY < -0.5) {
      _moveFocus(-1);
      moved = true;
    } else if (gp.buttons[15].pressed || axisX > 0.5) {
      _handleHorizontalNav(true); // Expand
      moved = true;
    } else if (gp.buttons[14].pressed || axisX < -0.5) {
      _handleHorizontalNav(false); // Collapse
      moved = true;
    }

    if (moved) {
      _lastGamepadUpdateTime = now;
    }
  }

  void _handleHorizontalNav(bool expand) {
    final active = web.document.activeElement;
    if (active == null) return;

    // If we are on a summary, toggle the parent details
    if (active.tagName.toLowerCase() == 'summary') {
      final details = active.parentElement as web.HTMLDetailsElement?;
      if (details != null) {
        details.open = expand;
      }
    } 
    // If we are on a save item, collapse its parent details
    else if (active.className.contains('save-item') && !expand) {
      final details = active.closest('details') as web.HTMLDetailsElement?;
      if (details != null) {
        details.open = false;
        (details.querySelector('summary') as web.HTMLElement?)?.focus();
      }
    }
  }

  void _goBack() {
    if (_selectionOverlay.style.display == 'flex') {
      _selectionCancel.click();
    } else if (_confirmOverlay.style.display == 'flex') {
      _confirmNo.click();
    } else if (_alertOverlay.style.display == 'flex') {
      _alertClose.click();
    } else if (_helpOverlay.style.display == 'flex') {
      _toggleHelp(false);
    } else if (_detailView.style.display == 'block') {
      _showWelcome();
    }
  }

  void _moveFocus(int direction) {
    web.HTMLElement? activeOverlay;
    if (_selectionOverlay.style.display == 'flex') activeOverlay = _selectionOverlay;
    else if (_confirmOverlay.style.display == 'flex') activeOverlay = _confirmOverlay;
    else if (_alertOverlay.style.display == 'flex') activeOverlay = _alertOverlay;
    else if (_helpOverlay.style.display == 'flex') activeOverlay = _helpOverlay;

    final container = activeOverlay ?? web.document.body as web.HTMLElement;
    final focusable = container.querySelectorAll('button, [tabindex="0"], a[href], input:not([type="hidden"]), summary');
    final list = <web.HTMLElement>[];
    
    for (var i = 0; i < focusable.length; i++) {
      final el = focusable.item(i) as web.HTMLElement;
      
      // Check if element is visible and has layout
      if (el.offsetParent != null && el.getClientRects().length > 0) {
        // Also ensure it's not inside a closed <details> element
        bool hiddenByDetails = false;
        web.Element? parent = el.parentElement;
        while (parent != null && parent != container) {
          if (parent.tagName.toLowerCase() == 'details') {
            if (!(parent as web.HTMLDetailsElement).open) {
              if (el.tagName.toLowerCase() != 'summary') {
                hiddenByDetails = true;
                break;
              }
            }
          }
          parent = parent.parentElement;
        }
        
        if (!hiddenByDetails) {
          list.add(el);
        }
      }
    }

    if (list.isEmpty) return;

    final current = web.document.activeElement as web.HTMLElement?;
    int index = current != null ? list.indexOf(current) : -1;
    
    index += direction;
    if (index < 0) index = list.length - 1;
    if (index >= list.length) index = 0;
    
    list[index].focus();
  }

  void _setupExportAll() {
    web.document.querySelector('#export-btn')?.addEventListener('click', (web.MouseEvent e) {
      _handleExportMenu();
    }.toJS);
  }

  Future<void> _handleExportMenu() async {
    final otherSlot = _activeSlot == 0 ? 1 : 0;
    final otherName = _activeSlot == 0 ? "Slot B" : "Slot A";
    
    final options = [
      SelectionOption(
        label: 'Export Card Image (.bin)',
        value: 'card',
        iconPath: 'icons/OG-XBOX-Card.svg',
      ),
      SelectionOption(
        label: 'Export All Saves to .zip',
        value: 'zip',
        iconPath: 'icons/zip.svg',
      ),
    ];

    if (_mus[otherSlot] != null) {
      options.add(SelectionOption(
        label: 'Transfer All to $otherName',
        value: 'transfer',
        iconPath: 'icons/inbox.svg',
      ));
    }

    final result = await _showSelection<String>('Export Options', options);

    if (result == 'card') {
      _exportCard();
    } else if (result == 'zip') {
      _exportAll();
    } else if (result == 'transfer') {
      _transferAll();
    }
  }

  Future<void> _transferAll() async {
    final targetSlot = _activeSlot == 0 ? 1 : 0;
    final targetMU = _mus[targetSlot];
    if (_mu == null || targetMU == null) return;

    if (await _showConfirm('Transfer All', 'Copy all saves from current card to ${targetSlot == 0 ? "Slot A" : "Slot B"}? Existing saves may be overwritten.')) {
      _showToast('Transferring...');
      try {
        final zip = _mu!.exportAll();
        targetMU.importZip(zip);
        _updateUI();
        _showToast('Transfer Complete');
      } catch (e) {
        _showModal('Transfer Error', 'Error during transfer: $e');
      }
    }
  }

  void _showModal(String title, String message) {
    _alertTitle.textContent = title;
    _alertMessage.textContent = message;
    _alertOverlay.style.display = 'flex';
    _alertClose.focus();
  }

  Future<bool> _showConfirm(String title, String message) {
    final completer = Completer<bool>();
    _confirmTitle.textContent = title;
    _confirmMessage.textContent = message;
    _confirmOverlay.style.display = 'flex';
    _confirmNo.focus();

    late web.EventListener yesListener;
    late web.EventListener noListener;

    yesListener = (web.Event e) {
      _confirmOverlay.style.display = 'none';
      _confirmYes.removeEventListener('click', yesListener);
      _confirmNo.removeEventListener('click', noListener);
      completer.complete(true);
    }.toJS;

    noListener = (web.Event e) {
      _confirmOverlay.style.display = 'none';
      _confirmYes.removeEventListener('click', yesListener);
      _confirmNo.removeEventListener('click', noListener);
      completer.complete(false);
    }.toJS;

    _confirmYes.addEventListener('click', yesListener);
    _confirmNo.addEventListener('click', noListener);

    return completer.future;
  }

  Future<T?> _showSelection<T>(String title, List<SelectionOption<T>> options) {
    final completer = Completer<T?>();
    _selectionTitle.textContent = title;
    _selectionOptions.innerHTML = ''.toJS;
    _selectionOverlay.style.display = 'flex';

    for (final option in options) {
      final isExternal = option.url != null && option.url!.startsWith('http');
      final el = web.document.createElement(isExternal ? 'a' : 'div') as web.HTMLElement;
      el.className = 'selection-item';
      el.tabIndex = 0;
      
      if (isExternal) {
        (el as web.HTMLAnchorElement).href = option.url!;
        (el as web.HTMLAnchorElement).target = '_blank';
      }

      final icon = web.document.createElement('img') as web.HTMLImageElement;
      icon.src = option.iconPath ?? 'icons/folder.svg';
      icon.className = 'xbox-icon';
      icon.style.filter = 'none';

      final text = web.document.createElement('span') as web.HTMLElement;
      text.textContent = option.label;

      el.appendChild(icon);
      el.appendChild(text);

      el.addEventListener('click', (web.Event e) {
        _selectionOverlay.style.display = 'none';
        if (!isExternal) {
          completer.complete(option.value ?? option as T);
        } else {
          completer.complete(null);
        }
      }.toJS);

      el.addEventListener('keydown', (web.KeyboardEvent e) {
        if (e.key == 'Enter' || e.key == ' ') {
          e.preventDefault();
          el.click();
        }
      }.toJS);

      _selectionOptions.appendChild(el);
    }

    if (_selectionOptions.children.length > 0) {
      (_selectionOptions.children.item(0) as web.HTMLElement).focus();
    } else {
      _selectionCancel.focus();
    }

    late web.EventListener cancelListener;
    cancelListener = (web.Event e) {
      _selectionOverlay.style.display = 'none';
      _selectionCancel.removeEventListener('click', cancelListener);
      if (!completer.isCompleted) completer.complete(null);
    }.toJS;

    _selectionCancel.addEventListener('click', cancelListener);

    return completer.future;
  }

  void _showToast(String message) {
    _toastMessage.textContent = message;
    _toast.style.display = 'flex';
    Timer(const Duration(seconds: 3), () {
      _toast.style.display = 'none';
    });
  }

  Future<void> _exportAll() async {
    if (_mu == null) {
      _showModal('Error', 'No Memory Unit loaded.');
      return;
    }
    
    final btn = web.document.querySelector('#export-btn') as web.HTMLButtonElement?;
    final textSpan = btn?.querySelector('span') as web.HTMLElement?;
    final originalText = textSpan?.textContent;
    if (textSpan != null) textSpan.textContent = 'Processing...';
    if (btn != null) btn.disabled = true;

    // Allow UI to update
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final bytes = _mu!.exportAll();
      _showToast('Exporting...');
      _downloadFile(bytes, 'all_saves.zip');
    } catch (e) {
      _showModal('Export Error', 'Error exporting all: $e');
    } finally {
      if (textSpan != null) textSpan.textContent = originalText ?? 'Export';
      if (btn != null) btn.disabled = false;
    }
  }

  void _setupEventListeners() {
    _alertClose.addEventListener('click', (web.MouseEvent e) {
      _alertOverlay.style.display = 'none';
    }.toJS);

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
        for (int i = 0; i < dt.files.length; i++) {
          _handleFile(dt.files.item(i)!);
        }
      }
    }.toJS);

    // File input events
    _fileInput.onchange = (web.Event e) {
      if (_fileInput.files != null && _fileInput.files!.length > 0) {
        for (int i = 0; i < _fileInput.files!.length; i++) {
          _handleFile(_fileInput.files!.item(i)!);
        }
      }
    }.toJS;

    _otherLinksBtn.addEventListener('click', (web.MouseEvent e) {
       _showSelection<String>('Other Links', [
         SelectionOption(label: 'XEMU Save Manager iso', url: 'https://github.com/BAD-AL/xbmut_web/tree/main/on_device_save_mgmt', iconPath: 'icons/link.svg'),
         SelectionOption(label: 'PS2 Save Manager', url: 'https://bad-al.github.io/mymc_web/', iconPath: 'icons/link.svg'),
         SelectionOption(label: 'Game Faqs XBOX Saves', url: 'https://gamefaqs.gamespot.com/pc/932095-halo-2/saves', iconPath: 'icons/link.svg'),
         SelectionOption(label: 'NFL2K4 Gamesave Editor', url: 'https://bad-al.github.io/nfl2k4tool_web/', iconPath: 'icons/link.svg'),
         SelectionOption(label: 'NFL2K5 Gamesave Editor', url: 'https://bad-al.github.io/nfl2k5tool_web/', iconPath: 'icons/link.svg'),
         SelectionOption(label: 'OG XBOX Emulator', url: 'https://xemu.app/', iconPath: 'icons/link.svg'),
       ]);
    }.toJS);

    _slotABtn.addEventListener('click', (web.MouseEvent e) {
      _switchSlot(0);
    }.toJS);

    _slotBBtn.addEventListener('click', (web.MouseEvent e) {
      _switchSlot(1);
    }.toJS);

    // Slot Tab Drag-and-Drop
    for (int i = 0; i < 2; i++) {
      final btn = i == 0 ? _slotABtn : _slotBBtn;
      btn.addEventListener('dragover', (web.DragEvent e) {
        e.preventDefault();
        btn.classList.add('active');
      }.toJS);

      btn.addEventListener('dragleave', (web.DragEvent e) {
        if (_activeSlot != i) {
          btn.classList.remove('active');
        }
      }.toJS);

      btn.addEventListener('drop', (web.DragEvent e) {
        e.preventDefault();
        if (_activeSlot != i) btn.classList.remove('active');
        final dt = e.dataTransfer;
        if (dt != null && dt.files.length > 0) {
          for (int j = 0; j < dt.files.length; j++) {
            _handleImportToSlot(dt.files.item(j)!, i);
          }
        }
      }.toJS);
    }

    web.document.querySelector('.help-icon-btn')?.addEventListener('click', (web.MouseEvent e) {
      _toggleHelp(true);
    }.toJS);

    web.document.querySelector('.help-icon-btn')?.addEventListener('keydown', (web.KeyboardEvent e) {
      if (e.key == 'Enter' || e.key == ' ') {
        e.preventDefault();
        _toggleHelp(true);
      }
    }.toJS);

    _helpOverlay.addEventListener('click', (web.MouseEvent e) {
      _toggleHelp(false);
    }.toJS);

    _helpOverlay.querySelector('.help-card')?.addEventListener('click', (web.MouseEvent e) {
      e.stopPropagation();
    }.toJS);

    web.document.querySelector('#help-dismiss-btn')?.addEventListener('click', (web.MouseEvent e) {
      _toggleHelp(false);
    }.toJS);

    final loadAction = (web.Event e) {
      e.preventDefault();
      _handleLoadSource();
    };

    _dropzone.addEventListener('click', loadAction.toJS);

    _dropzone.addEventListener('keydown', (web.KeyboardEvent e) {
      if (e.key == 'Enter' || e.key == ' ') {
        loadAction(e);
      }
    }.toJS);

    // Detail view buttons
    web.document.querySelector('#delete-save-btn')?.addEventListener('click', (web.MouseEvent e) {
      _deleteSelected();
    }.toJS);

    web.document.querySelector('#export-save-btn')?.addEventListener('click', (web.MouseEvent e) {
      _exportSelected();
    }.toJS);

    web.document.querySelector('#cancel-detail-btn')?.addEventListener('click', (web.MouseEvent e) {
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
          for (int i = 0; i < dt.files.length; i++) {
            _handleImport(dt.files.item(i)!);
          }
        }
      }
    }.toJS);

    // Global keyboard navigation
    web.window.addEventListener('keydown', (web.KeyboardEvent e) {
      if (e.key == 'Escape') {
        _goBack();
      } else if (e.key == 'ArrowDown') {
        e.preventDefault();
        _moveFocus(1);
      } else if (e.key == 'ArrowUp') {
        e.preventDefault();
        _moveFocus(-1);
      }
    }.toJS);
  }

  void _addCreateNewButton() {
    final btn = web.document.createElement('button') as web.HTMLButtonElement;
    btn.id = 'create-new-btn';
    btn.className = 'btn btn-subtle';
    btn.style.marginTop = '10px';
    btn.textContent = 'Create New Memory Unit';
    btn.onclick = (web.Event e) {
      e.stopPropagation();
      _handleCreateNewMenu();
    }.toJS;
    _dropzone.appendChild(btn);
  }

  Future<void> _handleLoadSource() async {
    final result = await _showSelection<String>('Load Source', [
      SelectionOption(label: 'From Computer', value: 'local', iconPath: 'icons/folder.svg'),
      SelectionOption(label: 'From Server (Curated)', value: 'server', iconPath: 'icons/logo_orb.svg'),
    ]);

    if (result == 'local') {
      _fileInput.click();
    } else if (result == 'server') {
      _handleLoadFromServer();
    }
  }

  Future<void> _handleLoadFromServer() async {
    final result = await _showSelection<SelectionOption>('Select Curated Save', [
      SelectionOption( label: 'AR-MAX XBOX part 1', url: 'saves/AR-MAX-XBOX_1.zip', iconPath: 'icons/zip.svg', tag: '64'),
      SelectionOption( label: 'AR-MAX XBOX part 2', url: 'saves/AR-MAX-XBOX_2.zip', iconPath: 'icons/zip.svg', tag: '64'),
      SelectionOption( label: 'AR-MAX XBOX part 3', url: 'saves/AR-MAX-XBOX_3.zip', iconPath: 'icons/zip.svg', tag: '64'),
      SelectionOption( label: 'AR-MAX XBOX part 5', url: 'saves/AR-MAX-XBOX_5.zip', iconPath: 'icons/zip.svg', tag: '64'),
      SelectionOption( label: 'AR-MAX XBOX part 7', url: 'saves/AR-MAX-XBOX_7.zip', iconPath: 'icons/zip.svg', tag: '64'),
      SelectionOption( label: 'AR-MAX XBOX part 2', url: 'saves/AR-MAX-XBOX_2.zip', iconPath: 'icons/zip.svg', tag: '64'),
      SelectionOption( label: 'AR-MAX XBOX part 4', url: 'saves/AR-MAX-XBOX_4.zip', iconPath: 'icons/zip.svg', tag: '64'),
      SelectionOption( label: 'AR-MAX XBOX part 6', url: 'saves/AR-MAX-XBOX_6.zip', iconPath: 'icons/zip.svg', tag: '64'),
      SelectionOption( label: 'AR-MAX XBOX part 8', url: 'saves/AR-MAX-XBOX_8.zip', iconPath: 'icons/zip.svg', tag: '64'),
      SelectionOption( label: 'AR-MAX Halo 1 and 2', url: 'saves/AR-MAX-XBOX_Halo-1-and-2.zip', iconPath: 'icons/zip.svg', tag: '16'),

      //SelectionOption( label:'AR-MAX Doom 3', url:'saves/AR-MAX-XBOX_DOOM-3.zip', iconPath: 'icons/zip.svg', tag: '64'),
      SelectionOption( label:'Mega-X-Key part 1', url:'saves/Mega-x-Saves_1.zip',iconPath: 'icons/zip.svg', tag: '64'),
      SelectionOption( label:'Mega-X-Key part 2', url:'saves/Mega-x-Saves_2.zip', iconPath: 'icons/zip.svg', tag: '8'),
      SelectionOption( label:'nfl2K5rosters.com part 1',  url: 'saves/nfl2k5rosters.com_1.zip',  iconPath: 'icons/zip.svg',  tag: '32'), 
      SelectionOption( label:'nfl2K5rosters.com part 2',  url: 'saves/nfl2k5rosters.com_2.zip',  iconPath: 'icons/zip.svg',  tag: '32'),
      SelectionOption( label:'nfl2K5rosters.com part 3',  url: 'saves/nfl2k5rosters.com_3.zip',  iconPath: 'icons/zip.svg',  tag: '32'),
      SelectionOption( label:'nfl2K5rosters.com Capa historic rosters 3',  url: 'saves/Capa_New_Historic3.2krosters.zip',  iconPath: 'icons/zip.svg',  tag: '32'),
      
      // Add more as needed
    ]);

    if (result != null) {
      if (result.url != null && result.url!.startsWith('http')) {
         web.window.open(result.url!, '_blank');
      } else {
         _loadSaveFromServer(result);
      }
    }
  }

  Future<void> _loadSaveFromServer(SelectionOption option) async {
    if (_mu != null) {
      final confirm = await _showConfirm('Replace Memory Unit', 'Loading from server will replace the current Memory Unit in Slot ${_activeSlot == 0 ? "A" : "B"}. Proceed?');
      if (!confirm) return;
    }

    _showToast('Downloading...');
    try {
      final response = await web.window.fetch(option.url!.toJS).toDart;
      if (!response.ok) throw Exception('Server responded with ${response.status}');
      
      final blob = await response.blob().toDart;
      final arrayBuffer = await blob.arrayBuffer().toDart;
      final bytes = arrayBuffer.toDart.asUint8List();

      final mbSize = int.tryParse(option.tag ?? '8') ?? 8;
      final sizeInBytes = mbSize * 1024 * 1024;

      _mus[_activeSlot] = XboxMemoryUnit.format(size: sizeInBytes);
      _fileNames[_activeSlot] = '${option.label.replaceAll(' ', '_')}.img';
      
      _mus[_activeSlot]!.importZip(bytes);
      _updateUI();
      _showToast('${option.label} Loaded Successfully');
    } catch (e) {
      _showModal('Download Error', 'Error downloading from server: $e');
    }
  }

  Future<void> _handleCreateNewMenu() async {
    final result = await _showSelection<int>('Select Card Capacity', [
      SelectionOption(label: '8 MB (Standard)', value: 8, iconPath: 'icons/OG-XBOX-Card.svg'),
      SelectionOption(label: '16 MB', value: 16, iconPath: 'icons/OG-XBOX-Card.svg'),
      SelectionOption(label: '32 MB', value: 32, iconPath: 'icons/OG-XBOX-Card.svg'),
      SelectionOption(label: '64 MB', value: 64, iconPath: 'icons/OG-XBOX-Card.svg'),
      SelectionOption(label: '128 MB', value: 128, iconPath: 'icons/OG-XBOX-Card.svg'),
    ]);

    if (result != null) {
      _createNewMU(result);
    }
  }

  void _toggleHelp(bool show) {
    _helpOverlay.style.display = show ? 'flex' : 'none';
  }

  Future<void> _handleImportToSlot(web.File file, int slot) async {
     final name = file.name.toLowerCase();
     if (!name.endsWith('.zip') && !name.endsWith('.bin') && !name.endsWith('.img')) return;
     
     final reader = web.FileReader();
     reader.readAsArrayBuffer(file);
     await reader.onLoadEnd.first;
     final bytes = (reader.result as JSArrayBuffer).toDart.asUint8List();
     
     if (name.endsWith('.zip')) {
       _showToast('Importing...');
       _importZipToSlot(bytes, slot);
     } else {
       _loadMUToSlot(bytes, file.name, slot);
     }
  }

  void _loadMUToSlot(Uint8List bytes, String name, int slot) {
    try {
      _mus[slot] = XboxMemoryUnit.fromBytes(bytes);
      _fileNames[slot] = name;
      _updateUI();
      _showToast('Memory Unit Loaded in Slot ${slot == 0 ? "A" : "B"}');
    } catch (e) {
      _showModal('Load Error', 'Error loading Memory Unit: $e');
    }
  }

  void _importZipToSlot(Uint8List zipBytes, int slot) {
    final mu = _mus[slot];
    if (mu == null) return;
    try {
      mu.importZip(zipBytes);
      _updateUI();
      _showToast('ZIP Imported into Slot ${slot == 0 ? "A" : "B"}');
    } catch (e) {
      _showModal('Import Error', 'Error importing ZIP: $e');
    }
  }

  Future<void> _handleFile(web.File file) async {
    final reader = web.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;
    
         final bytes = (reader.result as JSArrayBuffer).toDart.asUint8List();
        
        if (file.name.toLowerCase().endsWith('.zip')) {
          if (_mu == null) {
            _showModal('Error', 'Please load a Memory Unit (.bin) first before importing a .zip save.');
            return;
          }
          _showToast('Importing...');
          _importZip(bytes);
        } else {      _loadMU(bytes, file.name);
    }
  }

  Future<void> _handleImport(web.File file) async {
     if (!file.name.toLowerCase().endsWith('.zip')) return;
     _showToast('Importing...');
     
     final reader = web.FileReader();
     reader.readAsArrayBuffer(file);
     await reader.onLoadEnd.first;
     final bytes = (reader.result as JSArrayBuffer).toDart.asUint8List();
     _importZip(bytes);
  }

  void _loadMU(Uint8List bytes, String name) {
    try {
      _mus[_activeSlot] = XboxMemoryUnit.fromBytes(bytes);
      _fileNames[_activeSlot] = name;
      _updateUI();
      _showToast('Memory Unit Loaded in Slot ${_activeSlot == 0 ? "A" : "B"}');
    } catch (e) {
      _showModal('Load Error', 'Error loading Memory Unit: $e');
    }
  }

  void _createNewMU(int mbSize) {
    try {
      final sizeInBytes = mbSize * 1024 * 1024;
      _mus[_activeSlot] = XboxMemoryUnit.format(size: sizeInBytes);
      _fileNames[_activeSlot] = 'new_card_${mbSize}mb.img';
      _updateUI();
      _showToast('New ${mbSize}MB Memory Unit Created in Slot ${_activeSlot == 0 ? "A" : "B"}');
    } catch (e) {
      _showModal('Creation Error', 'Error creating Memory Unit: $e');
    }
  }

  void _importZip(Uint8List zipBytes) {
    if (_mu == null) return;
    try {
      _mu!.importZip(zipBytes);
      _updateUI();
      _showToast('ZIP Imported Successfully');
    } catch (e) {
      _showModal('Import Error', 'Error importing ZIP: $e');
    }
  }

  void _updateUI() {
    _slotAName.textContent = _fileNames[0] ?? 'Empty';
    _slotBName.textContent = _fileNames[1] ?? 'Empty';
    _slotAStats.textContent = _getSlotStats(0);
    _slotBStats.textContent = _getSlotStats(1);
    
    _slotABtn.title = 'Slot A: ${_fileNames[0] ?? "Empty"}';
    _slotBBtn.title = 'Slot B: ${_fileNames[1] ?? "Empty"}';

    if (_mu == null) {
      _infoDevice.innerHTML = '<strong>Device:</strong> none'.toJS;
      _infoCapacity.innerHTML = '<strong>Capacity:</strong> 0.0 MB'.toJS;
      _infoUsed.innerHTML = '<strong>Used:</strong> 0.0 MB'.toJS;
      _treeContainer.innerHTML = ''.toJS;
      _showWelcome();
      return;
    }

    // Update Header
    _infoDevice.innerHTML = '<strong>Device:</strong> $_fileName'.toJS;
    _infoCapacity.innerHTML = '<strong>Capacity:</strong> ${(_mu!.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB'.toJS;
    _infoUsed.innerHTML = '<strong>Used:</strong> ${((_mu!.totalBytes - _mu!.freeBytes) / 1024 / 1024).toStringAsFixed(1)} MB'.toJS;

    _renderTree();
    _showWelcome();
  }

  void _renderTree() {
    // Save expanded states
    final expandedTitles = <String>{};
    final detailElements = web.document.querySelectorAll('details.tree-item');
    for (int i = 0; i < detailElements.length; i++) {
      final details = detailElements.item(i) as web.HTMLDetailsElement;
      if (details.open) {
        final title = details.querySelector('.title-name-label')?.textContent;
        if (title != null) expandedTitles.add(title);
      }
    }

    _treeContainer.innerHTML = ''.toJS;
    if (_mu == null) return;

    for (final title in _mu!.titles) {
      final details = web.document.createElement('details') as web.HTMLDetailsElement;
      details.className = 'tree-item';
      if (expandedTitles.contains(title.name)) {
        details.open = true;
      }
      
      final summary = web.document.createElement('summary') as web.HTMLElement;
      summary.style.justifyContent = 'space-between';
      summary.tabIndex = 0; // Ensure it's in our focus list
      
      final summaryContent = web.document.createElement('div') as web.HTMLDivElement;
      summaryContent.style.display = 'flex';
      summaryContent.style.alignItems = 'center';
      summaryContent.style.gap = '10px';

      String iconsHtml = '<img src="icons/folder.svg" class="xbox-icon" alt="Folder">';
      if (title.titleImageBmp != null && title.titleImageBmp!.isNotEmpty) {
        final base64 = base64Encode(title.titleImageBmp!);
        iconsHtml += '<img src="data:image/bmp;base64,$base64" class="xbox-icon" style="border-radius:2px; filter:none;" alt="Game Icon">';
      }
      
      summaryContent.innerHTML = '$iconsHtml <span class="title-name-label">${title.name}</span>'.toJS;
      
      final deleteTitleBtn = web.document.createElement('img') as web.HTMLImageElement;
      deleteTitleBtn.src = 'icons/delete.svg';
      deleteTitleBtn.className = 'xbox-icon';
      deleteTitleBtn.style.cursor = 'pointer';
      deleteTitleBtn.title = 'Delete Entire Game Folder';
      deleteTitleBtn.tabIndex = 0;
      deleteTitleBtn.setAttribute('role', 'button');
      deleteTitleBtn.setAttribute('aria-label', 'Delete Entire Game Folder');
      deleteTitleBtn.style.borderRadius = '4px'; // Better focus ring shape
      deleteTitleBtn.style.padding = '2px';

      final deleteAction = (web.Event e) {
        e.stopPropagation();
        e.preventDefault();
        _deleteTitle(title.name);
      };

      deleteTitleBtn.onclick = deleteAction.toJS;
      deleteTitleBtn.onkeydown = (web.KeyboardEvent e) {
        if (e.key == 'Enter' || e.key == ' ') {
          deleteAction(e);
        }
      }.toJS;

      summary.appendChild(summaryContent);
      summary.appendChild(deleteTitleBtn);
      details.appendChild(summary);

      final saveList = web.document.createElement('div') as web.HTMLDivElement;
      saveList.className = 'save-list';
      
      for (final save in title.saves) {
        final saveItem = web.document.createElement('div') as web.HTMLDivElement;
        saveItem.className = 'save-item';
        saveItem.textContent = save.name;
        saveItem.tabIndex = 0;
        saveItem.setAttribute('role', 'button');
        
        final showAction = (web.Event e) {
          _showDetail(title.name, save.name);
        };
        
        saveItem.onclick = showAction.toJS;
        saveItem.onkeydown = (web.KeyboardEvent e) {
          if (e.key == 'Enter' || e.key == ' ') {
            e.preventDefault();
            _showDetail(title.name, save.name);
          }
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
    _viewFolder.textContent = save.folderName;
    _viewSize.textContent = '${(save.size / 1024).toStringAsFixed(0)} KB';
    _viewDate.textContent = _formatDate(save.modifiedAt);

    // Set icon if available
    if (save.saveImageBmp != null && save.saveImageBmp!.isNotEmpty) {
      final base64Image = base64Encode(save.saveImageBmp!);
      _viewIcon.src = 'data:image/bmp;base64,$base64Image';
    } else if (title.titleImageBmp != null && title.titleImageBmp!.isNotEmpty) {
      final base64Image = base64Encode(title.titleImageBmp!);
      _viewIcon.src = 'data:image/bmp;base64,$base64Image';
    } else {
      _viewIcon.src = 'https://via.placeholder.com/128x128/1a1a1a/107c10?text=SAVE';
    }

    _detailView.classList.remove('fade-in');
    // Trigger reflow
    _detailView.offsetWidth;
    _detailView.classList.add('fade-in');
  }

  Future<void> _deleteTitle(String titleName) async {
    if (_mu == null) return;
    if (await _showConfirm('Delete Game Folder', 'Are you sure you want to delete ALL saves for "$titleName"?')) {
      try {
        _mu!.delete(titleName);
        _updateUI();
        _showWelcome();
        _showToast('Game Folder Deleted');
      } catch (e) {
        _showModal('Delete Error', 'Error deleting title: $e');
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _deleteSelected() async {
    if (_mu == null) return;
    final path = '${_viewGame.textContent}/${_viewSave.textContent}';
    if (await _showConfirm('Delete Save', 'Are you sure you want to delete "$path"?')) {
      try {
        _mu!.delete(path);
        _updateUI();
        _showWelcome();
        _showToast('Save Deleted');
      } catch (e) {
        _showModal('Delete Error', 'Error deleting: $e');
      }
    }
  }

  void _exportSelected() async {
    if (_mu == null) return;
    final path = '${_viewGame.textContent}/${_viewSave.textContent}';
    final otherSlot = _activeSlot == 0 ? 1 : 0;
    final otherName = _activeSlot == 0 ? "Slot B" : "Slot A";

    final options = [
      SelectionOption(label: 'Export Save (.zip)', value: 'zip', iconPath: 'icons/zip.svg'),
    ];

    if (_mus[otherSlot] != null) {
      options.add(SelectionOption(label: 'Transfer to $otherName', value: 'transfer', iconPath: 'icons/inbox.svg'));
    }

    final result = await _showSelection<String>('Save Options', options);
    
    if (result == 'zip') {
      try {
        final bytes = _mu!.export(path);
        _showToast('Exporting...');
        _downloadFile(bytes, '${_viewSave.textContent}.zip');
      } catch (e) {
        _showModal('Export Error', 'Error exporting save: $e');
      }
    } else if (result == 'transfer') {
      _transferSelected(path);
    }
  }

  void _transferSelected(String path) {
    final targetSlot = _activeSlot == 0 ? 1 : 0;
    final targetMU = _mus[targetSlot];
    if (_mu == null || targetMU == null) return;

    _showToast('Transferring...');
    try {
      final bytes = _mu!.export(path);
      targetMU.importZip(bytes);
      _updateUI();
      _showToast('Transfer to ${targetSlot == 0 ? "Slot A" : "Slot B"} Complete');
    } catch (e) {
      _showModal('Transfer Error', 'Error during transfer: $e');
    }
  }

  void _exportCard() {
    if (_mu == null) return;
    try {
      _showToast('Exporting...');
      _downloadFile(_mu!.bytes, _fileName ?? 'card.img');
    } catch (e) {
      _showModal('Export Error', 'Error exporting card: $e');
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

class SelectionOption<T> {
  final String label;
  final T? value;
  final String? iconPath;
  final String? url;
  final String? tag;

  SelectionOption({
    required this.label,
    this.value,
    this.iconPath,
    this.url,
    this.tag,
  });
}
