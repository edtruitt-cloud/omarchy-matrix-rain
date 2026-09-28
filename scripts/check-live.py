#!/usr/bin/env python3
"""Reversible service lifecycle probe inside the running Omarchy shell.

Uses a unique temporary plugin ID and a brief fullscreen test window. Restores only its own config entries; preserves concurrent edits.
"""
import json,os,shutil,subprocess,tempfile,time,uuid
from pathlib import Path
root=Path(__file__).resolve().parents[1]
home=Path.home();test_id='ertiv.matrix-qa-'+uuid.uuid4().hex[:8]
target='matrix-qa-'+test_id.rsplit('-',1)[1]
plugin=home/'.config/omarchy/plugins'/test_id
config=home/'.config/omarchy/shell.json';original=config.read_bytes();original_data=json.loads(original)
report=root/'build/live';report.mkdir(parents=True,exist_ok=True)
recovery=report/(test_id+'-shell.json');recovery.write_bytes(original);recovery.chmod(0o600)
results=[]
probe=None
original_window=json.loads(subprocess.check_output(['hyprctl','-j','activewindow'],text=True)).get('address')

def command(*args):
    p=subprocess.run(args,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=8)
    if p.returncode: raise RuntimeError((args,p.stdout,p.stderr))
    return p.stdout.strip()

def ipc(method,*args): return command('omarchy-shell',target,method,*map(str,args))
def until(fn,timeout=8):
    end=time.monotonic()+timeout;last=None
    while time.monotonic()<end:
        try:
            last=fn()
            if last:return last
        except (RuntimeError,json.JSONDecodeError): pass
        time.sleep(.1)
    raise AssertionError('condition timed out: '+str(last))
def state():return json.loads(ipc('qaStatus'))

try:
    shutil.copytree(root,plugin,ignore=shutil.ignore_patterns('.git','build','dist','__pycache__'))
    for p in plugin.glob('*.qml'):p.write_text(p.read_text().replace('ertiv.matrix-rain',test_id).replace('target: "matrix-rain"','target: "'+target+'"'))
    manifest=json.loads((plugin/'manifest.json').read_text());manifest.update(id=test_id,name='Matrix Rain temporary QA',kinds=['service'],entryPoints={'service':'Service.qml'});manifest.pop('barWidget',None)
    (plugin/'manifest.json').write_text(json.dumps(manifest))
    service=plugin/'Service.qml';s=service.read_text().replace('    function ping(): string', '''    function qaStatus(): string { return JSON.stringify({phase:root.rainPhase,rendering:root.rendering}) }
    function qaMode(mode: string): string {
      root.pauseOnFullscreen=true; root.manualPaused=mode==="paused"
      var map=({}); if(mode==="fullscreen") for(var i=0;i<root.screens.length;i++) map[root.screens[i].name]=true
      root.fullscreenOverride=mode==="fullscreen"?map:null; return "ok"
    }
    function ping(): string''');service.write_text(s)
    command('omarchy-shell','shell','rescanPlugins')
    until(lambda: command('omarchy-shell','shell','setPluginEnabled',test_id,'true')=='ok')
    until(lambda:ipc('ping')=='ok')
    for mode in ('running','paused','running'):
        ipc('qaMode',mode);time.sleep(.25);a=state();time.sleep(.25);b=state()
        assert (b['phase']>a['phase'])==(mode=='running'),(mode,a,b)
        results.append({'mode':mode,'phase_delta':b['phase']-a['phase'],'rendering':b['rendering']})
    # Exercise a real compositor fullscreen event, not an overridden snapshot.
    probe_dir=report/(test_id+'-window');probe_dir.mkdir()
    (probe_dir/'shell.qml').write_text('import QtQuick\nimport Quickshell\nShellRoot { FloatingWindow { title: "'+target+'"; implicitWidth: 640; implicitHeight: 400; color: "#101315"; Text { anchors.centerIn: parent; color: "white"; text: "Matrix Rain fullscreen test" } } }')
    probe=subprocess.Popen(['quickshell','-p',str(probe_dir),'--no-color'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    client=until(lambda:next((c for c in json.loads(command('hyprctl','-j','clients')) if c.get('title')==target),None))
    command('hyprctl','dispatch','hl.dsp.focus({ window = '+json.dumps('address:'+client['address'])+' })')
    command('hyprctl','dispatch','hl.dsp.window.fullscreen_state({ internal = 2, client = 2 })')
    until(lambda:state()['rendering'] is False)
    a=state();time.sleep(.4);b=state();assert a['phase']==b['phase'],(a,b)
    results.append({'real_fullscreen':True,'phase_delta':b['phase']-a['phase']})
    probe.terminate();probe.wait(timeout=5);probe=None
    until(lambda:state()['rendering'] is True)
    if original_window:command('hyprctl','dispatch','hl.dsp.focus({ window = '+json.dumps('address:'+original_window)+' })')
    ipc('qaMode','paused')
    print(json.dumps(results,indent=2))
finally:
    if probe is not None:
        probe.terminate();probe.wait(timeout=5)
    if original_window:
        try:command('hyprctl','dispatch','hl.dsp.focus({ window = '+json.dumps('address:'+original_window)+' })')
        except Exception:pass
    try:command('omarchy-shell','shell','setPluginEnabled',test_id,'false')
    except Exception as e:print('Disable cleanup:',e)
    if plugin.exists():shutil.rmtree(plugin)
    state_dir=home/'.local/state'/test_id
    if state_dir.exists():shutil.rmtree(state_dir)
    current=json.loads(config.read_text())
    current['plugins']=[p for p in current.get('plugins',[]) if (p.get('id') if isinstance(p,dict) else p)!=test_id]
    current['disabledPlugins']=[p for p in current.get('disabledPlugins',[]) if p!=test_id]
    # Preserve exact bytes when no unrelated edit occurred.
    if current==original_data:config.write_bytes(original)
    else:config.write_text(json.dumps(current,indent=2)+'\n')
    command('omarchy-shell','shell','rescanPlugins')
    results.append({'restored':not plugin.exists(),'config_equal_to_original':json.loads(config.read_text())==original_data})
    (report/'results.json').write_text(json.dumps(results,indent=2)+'\n')
