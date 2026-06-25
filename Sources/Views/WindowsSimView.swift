import SwiftUI

// ======================== Windows giả lập (mô phỏng giao diện trong app) ========================
// Lưu ý: đây là BẢN MÔ PHỎNG giao diện Windows bằng web (HTML/CSS/JS) chạy trong app —
// không phải hệ điều hành thật và không chạy được file .exe. Dùng để trải nghiệm/giải trí.
struct WindowsSimView: View {
    var body: some View {
        NavigationStack {
            WebPreview(html: WindowsSimView.html, reloadToken: 1)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Windows giả lập")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    static let html = """
    <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
    <style>
    *{box-sizing:border-box;margin:0;padding:0;font-family:-apple-system,Segoe UI,Roboto,sans-serif;-webkit-user-select:none}
    html,body{height:100%;overflow:hidden}
    #desk{position:absolute;inset:0;background:linear-gradient(135deg,#1f6fd6,#0a3a7a 60%,#06203f);overflow:hidden}
    .ico{position:absolute;width:84px;text-align:center;color:#fff;text-shadow:0 1px 3px #0008;font-size:12px}
    .ico .g{width:46px;height:46px;margin:0 auto 4px;border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:24px;background:#ffffff20;backdrop-filter:blur(6px)}
    .win{position:absolute;top:18%;left:8%;width:84%;height:54%;background:#f3f3f3;border-radius:10px;box-shadow:0 18px 50px #000a;overflow:hidden;display:none;flex-direction:column}
    .bar{height:36px;background:#e6e6e6;display:flex;align-items:center;padding:0 8px;gap:8px;border-bottom:1px solid #00000014}
    .bar .t{font-size:13px;color:#222;flex:1}
    .dot{width:13px;height:13px;border-radius:50%;display:inline-block}
    .red{background:#ff5f57}.yel{background:#febc2e}.grn{background:#28c840}
    .body{flex:1;padding:12px;font-size:14px;color:#222;overflow:auto}
    textarea{width:100%;height:100%;border:none;outline:none;resize:none;font-size:15px;font-family:Consolas,monospace}
    #taskbar{position:absolute;left:0;right:0;bottom:0;height:50px;background:#1d1d1de0;backdrop-filter:blur(14px);display:flex;align-items:center;justify-content:center;gap:14px}
    #taskbar .tb{width:34px;height:34px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:18px;color:#fff;background:#ffffff14}
    #taskbar .tb:active{background:#ffffff33}
    #clock{position:absolute;right:14px;bottom:8px;color:#fff;font-size:11px;text-align:right;line-height:1.3}
    #start{position:absolute;left:50%;transform:translateX(-50%);bottom:58px;width:88%;max-width:520px;height:46%;background:#2b2b2bf0;backdrop-filter:blur(18px);border-radius:14px;box-shadow:0 18px 50px #000a;display:none;padding:16px;color:#fff}
    #start h4{font-size:13px;opacity:.7;margin-bottom:10px;font-weight:600}
    .grid{display:grid;grid-template-columns:repeat(4,1fr);gap:14px}
    .app{text-align:center;font-size:11px;color:#fff}
    .app .g{width:48px;height:48px;margin:0 auto 5px;border-radius:12px;background:#ffffff1f;display:flex;align-items:center;justify-content:center;font-size:24px}
    .app:active .g{background:#ffffff3a}
    </style></head>
    <body><div id="desk">
      <div class="ico" style="left:16px;top:16px" ondblclick="openWin('edge')" onclick="openWin('edge')"><div class="g">🌐</div>Edge</div>
      <div class="ico" style="left:16px;top:104px" onclick="openWin('note')"><div class="g">📝</div>Notepad</div>
      <div class="ico" style="left:16px;top:192px" onclick="openWin('pc')"><div class="g">💻</div>This PC</div>
      <div class="ico" style="left:16px;top:280px" onclick="openWin('store')"><div class="g">🛍️</div>Store</div>

      <div class="win" id="win">
        <div class="bar"><span class="dot red" onclick="closeWin()"></span><span class="dot yel"></span><span class="dot grn"></span>
          <span class="t" id="wt">Cửa sổ</span></div>
        <div class="body" id="wb"></div>
      </div>

      <div id="start">
        <h4>Đã ghim</h4>
        <div class="grid">
          <div class="app" onclick="openWin('edge')"><div class="g">🌐</div>Edge</div>
          <div class="app" onclick="openWin('note')"><div class="g">📝</div>Notepad</div>
          <div class="app" onclick="openWin('pc')"><div class="g">💻</div>This PC</div>
          <div class="app" onclick="openWin('store')"><div class="g">🛍️</div>Store</div>
          <div class="app" onclick="openWin('calc')"><div class="g">🧮</div>Calc</div>
          <div class="app" onclick="openWin('set')"><div class="g">⚙️</div>Cài đặt</div>
          <div class="app" onclick="openWin('game')"><div class="g">🎮</div>Game</div>
          <div class="app" onclick="openWin('term')"><div class="g">⬛</div>Terminal</div>
        </div>
      </div>

      <div id="taskbar">
        <div class="tb" onclick="toggleStart()" style="background:#0a84ff">⊞</div>
        <div class="tb" onclick="openWin('edge')">🌐</div>
        <div class="tb" onclick="openWin('note')">📝</div>
        <div class="tb" onclick="openWin('pc')">💻</div>
      </div>
      <div id="clock"></div>
    </div>
    <script>
    var apps={
      edge:{t:'Microsoft Edge',h:'<div style="text-align:center;padding:30px;color:#555">🌐<br><br>Trình duyệt mô phỏng.<br>Mở tab <b>Giải trí</b> trong app để lướt web thật.</div>'},
      note:{t:'Notepad',h:'<textarea placeholder="Gõ ghi chú ở đây..."></textarea>'},
      pc:{t:'This PC',h:'<div style="padding:6px"><b>Ổ đĩa</b><br>💽 Windows (C:) — 256GB<br>💾 Data (D:) — 512GB<br><br><b>Thiết bị</b><br>📁 Documents · 🖼️ Pictures · 🎵 Music</div>'},
      store:{t:'Microsoft Store',h:'<div style="padding:10px;color:#444">🛍️ Cửa hàng mô phỏng — danh sách ứng dụng mẫu.</div>'},
      calc:{t:'Máy tính',h:'<div style="text-align:center;font-size:40px;padding:30px">🧮<div style="font-size:14px;color:#666;margin-top:10px">Máy tính mô phỏng</div></div>'},
      set:{t:'Cài đặt',h:'<div style="padding:10px;color:#444">⚙️ Windows 11 Pro (mô phỏng)<br>Phiên bản: KENIOS Edition<br>RAM: 16GB · CPU: Apple Silicon</div>'},
      game:{t:'Game',h:'<div style="text-align:center;padding:20px"><button onclick="g()" style="font-size:18px;padding:12px 22px;border:none;border-radius:10px;background:#0a84ff;color:#fff">Bấm +1: <span id="sc">0</span></button></div>'},
      term:{t:'Terminal',h:'<div style="background:#0c0c0c;color:#0f0;font-family:monospace;padding:10px;height:100%">C:\\\\Users\\\\KENIOS> echo Xin chao<br>Xin chao<br>C:\\\\Users\\\\KENIOS> _</div>'}
    };
    var sc=0;
    function g(){sc++;document.getElementById('sc').innerText=sc;}
    function openWin(k){var a=apps[k];if(!a)return;document.getElementById('wt').innerText=a.t;document.getElementById('wb').innerHTML=a.h;document.getElementById('win').style.display='flex';document.getElementById('start').style.display='none';}
    function closeWin(){document.getElementById('win').style.display='none';}
    function toggleStart(){var s=document.getElementById('start');s.style.display=s.style.display==='block'?'none':'block';}
    function tick(){var d=new Date();var hh=('0'+d.getHours()).slice(-2),mm=('0'+d.getMinutes()).slice(-2);document.getElementById('clock').innerHTML=hh+':'+mm+'<br>'+d.toLocaleDateString('vi-VN');}
    tick();setInterval(tick,1000);
    </script></body></html>
    """
}
