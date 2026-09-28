#!/usr/bin/env python3
"""Measure an isolated real Wayland service with per-process CPU/DRM counters.

Each scenario applies a weather preset plus optional rain settings, e.g.
Storm with all five depth layers, then samples running and paused rain."""
import json,os,re,shutil,subprocess,tempfile,time
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'build';out.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='matrix-perf-') as tmp:
    tmp=Path(tmp);(tmp/'Synth').symlink_to(root);(tmp/'home').mkdir()
    for name in ('Commons','Ui','services'):
        (tmp/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (tmp/'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "Synth" as Synth
ShellRoot {
  Synth.Service { id: svc; pauseOnFullscreen: false; manifest: ({__sourceDir: Quickshell.env("MATRIX_SOURCE")}) }
  IpcHandler { target: "bench"
    function mode(value: string): string { svc.manualPaused=value==="paused"; return "ok" }
    function status(): string { return JSON.stringify({rendering:svc.rendering,phase:svc.rainPhase}) }
    function setup(json: string): string {
      var c = JSON.parse(json)
      if (c.preset) svc.applyRainPreset(c.preset)
      for (var k in c) if (k !== "preset") svc.setRainOption(k, c[k])
      return JSON.stringify({preset: svc.rainPreset, layers: svc.depthOn ? svc.depthLayers : 0, letterSize: svc.letterSize})
    }
  }
}
''')
    env=dict(os.environ,HOME=str(tmp/'home'),XDG_STATE_HOME=str(tmp/'home/.local/state'),XDG_CONFIG_HOME=str(tmp/'home/.config'),MATRIX_SOURCE=str(root),QT_QPA_PLATFORM='wayland')
    env.pop('QT_QUICK_BACKEND',None)
    log=open(out/'rain-render.log','w')
    proc=subprocess.Popen(['quickshell','-p',str(tmp),'--no-color'],env=env,stdout=log,stderr=subprocess.STDOUT)
    def call(method,*args):
        p=subprocess.run(['qs','ipc','-p',str(tmp),'call','bench',method,*args],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=3)
        if p.returncode:raise RuntimeError(p.stderr)
        return p.stdout.strip()
    def counters():
        stat=Path('/proc',str(proc.pid),'stat').read_text().rsplit(')',1)[1].split()
        cpu=(int(stat[11])+int(stat[12]))/os.sysconf('SC_CLK_TCK')
        engines={};clients=set()
        for path in Path('/proc',str(proc.pid),'fdinfo').iterdir():
            try:text=path.read_text()
            except OSError:continue
            client=re.search(r'drm-client-id:\s*(\d+)',text)
            if not client or client.group(1) in clients:continue
            clients.add(client.group(1))
            for key,value in re.findall(r'(drm-engine-[\w-]+):\s*(\d+)\s+ns',text):engines[key]=engines.get(key,0)+int(value)
        return {'cpu':cpu,'engines':engines}
    try:
        end=time.monotonic()+10
        while True:
            if proc.poll() is not None:raise RuntimeError('renderer exited: '+(out/'rain-render.log').read_text())
            try:json.loads(call('status'));break
            except (RuntimeError,json.JSONDecodeError):
                if time.monotonic()>end:raise
                time.sleep(.1)
        results=[]
        scenarios=[('classic',{'preset':'classic'}),
                   ('storm 5 layers, sharp',{'preset':'storm','depthQuality':'sharp'}),
                   ('storm 5 layers, balanced',{'preset':'storm','depthQuality':'balanced'}),
                   ('storm 5 layers, fast',{'preset':'storm','depthQuality':'fast'}),
                   ('storm, depth off',{'preset':'storm','depthLevel':0})]
        for name,config in scenarios:
            applied=json.loads(call('setup',json.dumps(config)))
            for mode in ('running','paused'):
                call('mode',mode);time.sleep(.5)
                state1=json.loads(call('status'));a=counters();start=time.monotonic();time.sleep(3);b=counters();elapsed=time.monotonic()-start;state2=json.loads(call('status'))
                results.append({'scenario':name,'applied':applied,'mode':mode,'seconds':elapsed,'cpu_percent_one_core':100*(b['cpu']-a['cpu'])/elapsed,'gpu_engine_percent':{key:100*(value-a['engines'].get(key,0))/(elapsed*1e9) for key,value in b['engines'].items()},'phase_delta':state2['phase']-state1['phase']})
        (out/'rain-performance.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2))
    finally:
        proc.terminate()
        try:proc.wait(timeout=5)
        except subprocess.TimeoutExpired:proc.kill();proc.wait()
        log.close()
