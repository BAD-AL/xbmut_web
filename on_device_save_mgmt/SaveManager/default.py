import xbmc
import xbmcgui
import os
import shutil

# --- Configuration ---
HDD_UDATA = "E:\\UDATA\\"
MEMORY_UNITS = [
    ('1-A', 'H:\\'), ('1-B', 'I:\\'), ('2-A', 'J:\\'), ('2-B', 'K:\\'),
    ('3-A', 'L:\\'), ('3-B', 'M:\\'), ('4-A', 'N:\\'), ('4-B', 'O:\\'),
]

def safe_str(val):
    if val is None: return "Unknown"
    try:
        if isinstance(val, unicode): return val.encode('utf-8', 'ignore')
        return str(val)
    except: return "Encoding Error"

def get_xbx_value(file_path, key):
    if not os.path.exists(file_path): return None
    f = None
    try:
        f = open(file_path, 'rb')
        raw = f.read()
        f.close()
        try:
            content = raw.decode('utf-16')
        except:
            content = raw.decode('utf-8', 'ignore')
        for line in content.splitlines():
            if '=' in line:
                parts = line.split('=', 1)
                if len(parts) == 2:
                    k = parts[0].strip().lower()
                    v = parts[1].strip()
                    if k == key.lower(): return v
    except:
        if f: f.close()
    return None

def get_game_name(tid_path):
    name = get_xbx_value(os.path.join(tid_path, 'TitleMeta.xbx'), 'TitleName')
    if name: return name
    return os.path.basename(tid_path)

def get_save_name(sid_path):
    name = get_xbx_value(os.path.join(sid_path, 'SaveMeta.xbx'), 'Name')
    if name: return name
    return os.path.basename(sid_path)

def is_device_ready(path):
    if "UDATA" in path: return True
    tmp_path = os.path.join(path, "probe.tmp")
    try:
        f = open(tmp_path, "w"); f.write("probe"); f.close()
        os.remove(tmp_path)
        return True
    except: return False

def cleanup_empty_dir(path):
    """Deletes a directory if it contains no subdirectories (only loose files like .xbx)."""
    try:
        if not os.path.exists(path): return
        items = os.listdir(path)
        has_subdirs = False
        for item in items:
            if os.path.isdir(os.path.join(path, item)):
                has_subdirs = True; break
        if not has_subdirs:
            shutil.rmtree(path)
    except: pass

def run_manager():
    dialog = xbmcgui.Dialog()
    
    while True:
        # 1. Detect Devices
        devices = [('XBOX HDD', HDD_UDATA)]
        for label, path in MEMORY_UNITS:
            if is_device_ready(path): devices.append(("MU " + label, path))
        
        device_labels = [safe_str(d[0]) for d in devices]
        device_labels.append("[ Refresh Devices ]")
        
        idx = dialog.select("SELECT DEVICE", device_labels)
        if idx < 0: break
        if idx == len(devices): continue
        active_label, active_path = devices[idx]
        
        # 2. Select Game
        while True:
            games = []
            if os.path.exists(active_path):
                try:
                    items = os.listdir(active_path)
                    items.sort()
                    for tid in items:
                        p = os.path.join(active_path, tid)
                        if os.path.isdir(p):
                            games.append((p, get_game_name(p)))
                except: pass
            
            if not games:
                dialog.ok(active_label, "No games found.")
                break
                
            game_labels = [safe_str(g[1]) for g in games]
            g_idx = dialog.select("GAMES: " + active_label, game_labels)
            if g_idx < 0: break
            
            selected_game_path, selected_game_name = games[g_idx]
            
            # 3. Select Save
            while True:
                saves = []
                if os.path.exists(selected_game_path):
                    try:
                        items = os.listdir(selected_game_path)
                        items.sort()
                        for sid in items:
                            p = os.path.join(selected_game_path, sid)
                            if os.path.isdir(p) and sid not in ['TitleMeta.xbx', 'TitleImage.xbx']:
                                saves.append((p, get_save_name(p)))
                    except: pass
                
                # Build Save Menu
                save_display_labels = ["[ DELETE ENTIRE GAME DATA ]"]
                for s in saves: save_display_labels.append(safe_str(s[1]))
                
                s_idx = dialog.select("SAVES: " + selected_game_name, save_display_labels)
                if s_idx < 0: break
                
                # Case A: Delete Entire Game
                if s_idx == 0:
                    if dialog.yesno("WARNING", "Delete ALL saves for " + selected_game_name + "?"):
                        try:
                            shutil.rmtree(selected_game_path)
                            dialog.ok("Deleted", "Game data removed.")
                            break # Go back to game select
                        except Exception, e: dialog.ok("Error", safe_str(e))
                    continue
                
                # Case B: Save Selected (Offset by 1 because of the Delete Game entry)
                selected_save_path, selected_save_name = saves[s_idx - 1]
                
                # 4. Action Menu for Save
                action_idx = dialog.select("ACTION: " + safe_str(selected_save_name), ["Copy To...", "Delete Save"])
                if action_idx < 0: continue
                
                # Copy Workflow
                if action_idx == 0:
                    options = [d for d in devices if d[1] != active_path]
                    if not options:
                        dialog.ok("Copy", "No other devices detected."); continue
                    
                    target_labels = [safe_str(o[0]) for o in options]
                    dest_idx = dialog.select("COPY TO:", target_labels)
                    if dest_idx >= 0:
                        dest_label, dest_base = options[dest_idx]
                        src_title_dir = os.path.dirname(selected_save_path)
                        title_id = os.path.basename(src_title_dir)
                        save_id = os.path.basename(selected_save_path)
                        target_title_dir = os.path.join(dest_base, title_id)
                        target_save_path = os.path.join(target_title_dir, save_id)
                        
                        if dialog.yesno("Confirm", "Copy save to " + dest_label + "?"):
                            try:
                                if not os.path.exists(target_title_dir): os.makedirs(target_title_dir)
                                for item in os.listdir(src_title_dir):
                                    item_path = os.path.join(src_title_dir, item)
                                    if os.path.isfile(item_path): shutil.copy2(item_path, os.path.join(target_title_dir, item))
                                if os.path.exists(target_save_path): shutil.rmtree(target_save_path)
                                shutil.copytree(selected_save_path, target_save_path)
                                dialog.ok("Success", "Transfer Complete!")
                            except Exception, e: dialog.ok("Error", safe_str(e))
                
                # Delete Save Workflow
                elif action_idx == 1:
                    if dialog.yesno("Confirm", "Delete this specific save?"):
                        try:
                            shutil.rmtree(selected_save_path)
                            # Cleanup Title folder if it's now empty of saves
                            cleanup_empty_dir(os.path.dirname(selected_save_path))
                            dialog.ok("Deleted", "Save removed.")
                        except Exception, e: dialog.ok("Error", safe_str(e))

if __name__ == '__main__':
    try: run_manager()
    except Exception, e: xbmcgui.Dialog().ok("Critical Error", safe_str(e))
