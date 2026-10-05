import os
import re
import sys

# Optional argument: the export folder to patch (default build/web; the Toss build uses build/toss)
WEB_DIR = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "web"))
js_path = os.path.join(WEB_DIR, "index.js")
html_path = os.path.join(WEB_DIR, "index.html")

print("Patching index.js...")
with open(js_path, "r", encoding="utf-8") as f:
    s = f.read()

s1 = 'GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path);'
r1 = 'GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet?ctx.audioWorklet.addModule(path):Promise.resolve();'

s2 = 'async connectPositionWorklet(start){await GodotAudio.audioPositionWorkletPromise;if(this.isCanceled){return}this._source.connect(this.getPositionWorklet());if(start){this.start()}}'
r2 = 'async connectPositionWorklet(start){if(GodotAudio.audioPositionWorkletPromise){await GodotAudio.audioPositionWorkletPromise;}if(this.isCanceled){return}if(GodotAudio.ctx&&GodotAudio.ctx.audioWorklet&&typeof AudioWorkletNode!=="undefined"){this._source.connect(this.getPositionWorklet());}if(start){this.start()}}'

if s1 in s:
    s = s.replace(s1, r1, 1)
    print("Patched audioPositionWorkletPromise in index.js")

if s2 in s:
    s = s.replace(s2, r2, 1)
    print("Patched connectPositionWorklet in index.js")

# Expose the audio context so the page can pause sound while the app is in the background
s3 = 'GodotAudio.ctx=ctx;'
if s3 in s and 'window.__godotAudioCtx' not in s:
    s = s.replace(s3, 'GodotAudio.ctx=ctx;window.__godotAudioCtx=ctx;', 1)
    print("Exposed the audio context in index.js")

# No code from strings: the engine ships JavaScriptBridge.eval() as a JS function that calls
# eval(). The game never uses it, and Apps in Toss rejects any eval in the bundle, so the function
# is replaced by one that runs nothing (the wasm import name "godot_js_eval" has to stay).
EVAL_FN = 'function _godot_js_eval('
if EVAL_FN in s:
    start = s.index(EVAL_FN)
    depth = 0
    end = s.index('{', start)
    for i in range(end, len(s)):
        if s[i] == '{':
            depth += 1
        elif s[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    stub = 'function _godot_js_noexec(p_js,p_use_global_ctx,p_union_ptr,p_byte_arr,p_byte_arr_write,p_callback){return 0}'
    s = s[:start] + stub + s[end:]
    s = s.replace('_godot_js_eval', '_godot_js_noexec')
    print("Disabled JavaScriptBridge.eval in index.js")
if re.search(r'(?<![\w$])eval\s*\(|new Function|(?<![\w$.])Function\s*\(', s):
    print("ERROR: index.js still runs code from strings (eval / Function)")
    sys.exit(1)

with open(js_path, "w", encoding="utf-8") as f:
    f.write(s)

print("Patching index.html...")
with open(html_path, "r", encoding="utf-8") as f:
    html = f.read()

# Filter out secure context requirement if threads are disabled
old_missing = '''\tconst missing = Engine.getMissingFeatures({
\t\tthreads: GODOT_THREADS_ENABLED,
\t});'''

new_missing = '''\tconst missing = Engine.getMissingFeatures({
\t\tthreads: GODOT_THREADS_ENABLED,
\t}).filter(function(item) {
\t\treturn !item.toLowerCase().includes('secure context');
\t});'''

if old_missing in html:
    html = html.replace(old_missing, new_missing, 1)
    print("Patched secure context check in index.html")

# Set Page Title and Favicon
html = re.sub(r"<title>.*?</title>", "<title>퍼즐블록 (PuzzleBlock)</title>", html, count=1)

# Responsive Full-Screen Canvas styling (NO max-width squishing so PC fills the full monitor height!)
custom_css = """
<style>
  html, body {
    margin: 0;
    padding: 0;
    border: 0;
    background-color: #070b14;
    color: #e2e8f0;
    overflow: hidden;
    touch-action: none;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    user-select: none;
    width: 100vw;
    height: 100vh;
  }
  #canvas {
    display: block;
    margin: 0 auto;
  }
  #canvas:focus {
    outline: none;
  }
</style>
"""

# Stop all sound the moment the page is hidden (app sent to background, screen off) and bring it
# back when it returns. Required by Apps in Toss, and nicer on the web too.
background_audio = """
<script>
  (function () {
    function sync() {
      var ctx = window.__godotAudioCtx;
      if (!ctx) return;
      if (document.hidden) { if (ctx.state === "running") ctx.suspend(); }
      else if (ctx.state === "suspended") { ctx.resume(); }
    }
    document.addEventListener("visibilitychange", sync);
    window.addEventListener("pagehide", sync);
    window.addEventListener("pageshow", sync);
  })();
</script>
"""

if "</head>" in html and "__godotAudioCtx" not in html:
    html = html.replace("</head>", custom_css + background_audio + "\n</head>")

with open(html_path, "w", encoding="utf-8") as f:
    f.write(html)

print("Patching finished successfully!")
