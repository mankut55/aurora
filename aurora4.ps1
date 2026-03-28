Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===========================================================
#   C# — WinAPI + LockButton + SimpleSlider + AppTile + AuroraDeck
# ===========================================================
$_needsCompile = $false
try {
    # Sprawdz czy mamy nowa wersje z obsuga motywow (pole DECK_VER)
    if (-not ([System.Management.Automation.PSTypeName]'AuroraDeck').Type) { $_needsCompile = $true }
    elseif ([AuroraDeck]::DECK_VER -ne "magnet_glass6") { $_needsCompile = $true }
} catch { $_needsCompile = $true }

if ($_needsCompile) {
try {
Add-Type @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class WinAPI {
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, IntPtr w, IntPtr l);
    public const int WM_NCLBUTTONDOWN = 0xA1;
    public const int HTCAPTION = 0x2;
}

// ─── Double Buffered Panels (Fix Migotania) ──────────────────────────────────
public class DBPanel : Panel {
    public DBPanel() {
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint |
                 ControlStyles.AllPaintingInWmPaint | ControlStyles.SupportsTransparentBackColor, true);
        UpdateStyles();
    }
}

public class DBFlowPanel : FlowLayoutPanel {
    public DBFlowPanel() {
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint |
                 ControlStyles.AllPaintingInWmPaint | ControlStyles.SupportsTransparentBackColor, true);
        UpdateStyles();
    }
}

// ─── AuroraTimer — jeden globalny timer dla wszystkich kontrolek ──────────────
public static class AuroraTimer {
    private static readonly Timer _timer;
    public  static          float Time { get; private set; }
    public  static event    EventHandler Tick;

    static AuroraTimer() {
        _timer          = new Timer { Interval = 30 };
        _timer.Tick    += (s, e) => {
            Time += 0.05f;
            if (Time >= (float)(Math.PI * 20.0)) Time -= (float)(Math.PI * 20.0);
            if (Tick != null) Tick(null, EventArgs.Empty);
        };
        _timer.Start();
    }

    public static void Pause()  { }
    public static void Resume() { }
}

// ─── LockButton ──────────────────────────────────────────────────────────────
public class LockButton : Control {
    private bool  _locked  = true;
    private bool  _hover   = false;
    private bool  _pressed = false;

    public bool IsLocked { get { return _locked; } }
    public event EventHandler LockChanged;

    public void SetLocked(bool v) { _locked = v; Invalidate(); }

    public LockButton() {
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint |
                 ControlStyles.AllPaintingInWmPaint | ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        Cursor    = Cursors.Hand;
        AuroraTimer.Tick += OnGlobalTick;
        MouseEnter += (s, e) => { _hover   = true;  Invalidate(); };
        MouseLeave += (s, e) => { _hover   = false; _pressed = false; Invalidate(); };
        MouseDown  += (s, e) => { if (((MouseEventArgs)e).Button == MouseButtons.Left) { _pressed = true;  Invalidate(); } };
        MouseUp    += (s, e) => {
            if (_pressed && ((MouseEventArgs)e).Button == MouseButtons.Left) {
                _locked = !_locked;
                _pressed = false;
                if (LockChanged != null) LockChanged(this, EventArgs.Empty);
                Invalidate();
            }
        };
    }

    private void OnGlobalTick(object s, EventArgs e) { if (!IsDisposed) Invalidate(); }

    protected override void Dispose(bool disposing) {
        if (disposing) AuroraTimer.Tick -= OnGlobalTick;
        base.Dispose(disposing);
    }

    protected override void OnPaint(PaintEventArgs e) {
        var g = e.Graphics;
        g.SmoothingMode     = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;

        int W = Width, H = Height;
        float cx = W / 2f, cy = H / 2f;
        float pulse = (float)Math.Sin(AuroraTimer.Time * 4f) * 0.2f + 0.8f;

        var _ff2 = this.FindForm(); int thm = (_ff2 != null && _ff2.Tag is int) ? (int)_ff2.Tag : 0;
        int   baseA  = _hover ? (int)(190 * pulse) : (int)(110 * pulse);
        Color clrMain;
        if (thm == 2) { // Jasny
            clrMain = _locked ? Color.FromArgb(baseA, 180, 60, 60) : Color.FromArgb(baseA, 50, 130, 50);
        } else if (thm == 3) { // Matowy / Szklo
            clrMain = _locked ? Color.FromArgb(baseA, 190, 80, 80) : Color.FromArgb(baseA, 80, 180, 150);
        } else {
            clrMain = _locked ? Color.FromArgb(baseA, 200, 100, 100) : Color.FromArgb(baseA, 100, 220, 160);
        }

        float bx = cx - 6f, by = cy - 1f, bw = 12f, bh = 10f;
        using (var bp = new GraphicsPath()) {
            float br = 2.5f, bd = br * 2;
            bp.AddArc(bx,          by,          bd, bd, 180, 90);
            bp.AddArc(bx + bw - bd, by,          bd, bd, 270, 90);
            bp.AddArc(bx + bw - bd, by + bh - bd, bd, bd,   0, 90);
            bp.AddArc(bx,          by + bh - bd, bd, bd,  90, 90);
            bp.CloseFigure();
            using (var fill = new SolidBrush(Color.FromArgb(baseA / 4, clrMain)))
                g.FillPath(fill, bp);
            using (var pen = new Pen(clrMain, 1.4f))
                g.DrawPath(pen, bp);
        }

        using (var hb = new SolidBrush(clrMain))
            g.FillEllipse(hb, cx - 1.8f, by + bh * 0.28f, 3.6f, 3.6f);

        float arcX = cx - 4.5f, arcW = 9f, arcH = 9f;
        using (var pen = new Pen(clrMain, 1.6f)) {
            pen.StartCap = System.Drawing.Drawing2D.LineCap.Round;
            pen.EndCap   = System.Drawing.Drawing2D.LineCap.Round;
            if (_locked) {
                g.DrawArc(pen, arcX, cy - arcH, arcW, arcH, 180, 180);
            } else {
                g.DrawArc(pen, arcX + 3f, cy - arcH + 1f, arcW, arcH, 200, 160);
            }
        }
    }
}

// ─── PinButton ───────────────────────────────────────────────────────────────
public class PinButton : Control {
    private bool  _pinned  = false;
    private bool  _hover   = false;
    private bool  _pressed = false;

    public bool IsPinned { get { return _pinned; } }
    public event EventHandler PinChanged;

    public PinButton() {
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint |
                 ControlStyles.AllPaintingInWmPaint | ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        Cursor    = Cursors.Hand;
        AuroraTimer.Tick += OnGlobalTick;
        MouseEnter += (s, e) => { _hover   = true;  Invalidate(); };
        MouseLeave += (s, e) => { _hover   = false; _pressed = false; Invalidate(); };
        MouseDown  += (s, e) => { if (((MouseEventArgs)e).Button == MouseButtons.Left) { _pressed = true;  Invalidate(); } };
        MouseUp    += (s, e) => {
            if (_pressed && ((MouseEventArgs)e).Button == MouseButtons.Left) {
                _pinned  = !_pinned;
                _pressed = false;
                if (PinChanged != null) PinChanged(this, EventArgs.Empty);
                Invalidate();
            }
        };
    }

    private void OnGlobalTick(object s, EventArgs e) { if (!IsDisposed) Invalidate(); }

    protected override void Dispose(bool disposing) {
        if (disposing) AuroraTimer.Tick -= OnGlobalTick;
        base.Dispose(disposing);
    }

    protected override void OnPaint(PaintEventArgs e) {
        var g = e.Graphics;
        g.SmoothingMode     = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;

        int   W = Width, H = Height;
        float cx = W / 2f, cy = H / 2f;
        float pulse = (float)Math.Sin(AuroraTimer.Time * 4f) * 0.2f + 0.8f;

        int baseA = _hover ? (int)(210 * pulse) : (int)(130 * pulse);
        Color clrOn  = Color.FromArgb(baseA, 80,  210, 120);
        Color clrOff = Color.FromArgb(baseA, 215, 70,  70);
        Color clrMain = _pinned ? clrOn : clrOff;

        int glowA = (int)(30 * pulse);
        Color glowCol = _pinned ? Color.FromArgb(glowA, 60, 200, 100) : Color.FromArgb(glowA, 200, 60, 60);
        using (var gb = new SolidBrush(glowCol))
            g.FillEllipse(gb, cx - 8f, cy - 8f, 16f, 16f);

        float arcR = 5.5f, arcTop = cy - 7.5f;
        var arcRect = new System.Drawing.RectangleF(cx - arcR, arcTop, arcR * 2f, arcR * 2f);
        using (var pen = new Pen(clrMain, 2.3f)) {
            pen.StartCap = System.Drawing.Drawing2D.LineCap.Round;
            pen.EndCap   = System.Drawing.Drawing2D.LineCap.Round;
            g.DrawArc(pen, arcRect, 180f, 180f);
        }

        using (var pen = new Pen(clrMain, 2.3f)) {
            pen.StartCap = System.Drawing.Drawing2D.LineCap.Round;
            pen.EndCap   = System.Drawing.Drawing2D.LineCap.Flat;
            g.DrawLine(pen, cx - arcR, arcTop + arcR, cx - arcR, cy + 4f);
            g.DrawLine(pen, cx + arcR, arcTop + arcR, cx + arcR, cy + 4f);
        }

        using (var pN = new Pen(Color.FromArgb(baseA, 80, 210, 120), 2.8f)) {
            pN.StartCap = System.Drawing.Drawing2D.LineCap.Flat;
            pN.EndCap   = System.Drawing.Drawing2D.LineCap.Round;
            g.DrawLine(pN, cx - arcR, cy + 3f, cx - arcR, cy + 6.5f);
        }
        using (var pS = new Pen(Color.FromArgb(baseA, 215, 70, 70), 2.8f)) {
            pS.StartCap = System.Drawing.Drawing2D.LineCap.Flat;
            pS.EndCap   = System.Drawing.Drawing2D.LineCap.Round;
            g.DrawLine(pS, cx + arcR, cy + 3f, cx + arcR, cy + 6.5f);
        }

        if (_pinned) {
            int spkA = (int)(160 * pulse);
            using (var sp = new Pen(Color.FromArgb(spkA, 255, 240, 120), 1.0f)) {
                sp.StartCap = System.Drawing.Drawing2D.LineCap.Round;
                sp.EndCap   = System.Drawing.Drawing2D.LineCap.Round;
                g.DrawLine(sp, cx - arcR - 1f, cy + 4f, cx - arcR - 3f, cy + 2f);
                g.DrawLine(sp, cx - arcR - 1f, cy + 4f, cx - arcR - 3f, cy + 6f);
                g.DrawLine(sp, cx + arcR + 1f, cy + 4f, cx + arcR + 3f, cy + 2f);
                g.DrawLine(sp, cx + arcR + 1f, cy + 4f, cx + arcR + 3f, cy + 6f);
            }
        }
    }
}

// ─── SimpleSlider ────────────────────────────────────────────────────────────
public class SimpleSlider : Control {
    private int   _min = 70, _max = 180, _value = 110;
    private bool  _drag = false;
    private const int THUMB_R = 7;
    private const int PAD     = THUMB_R + 3;

    public int Minimum { get { return _min; } set { _min = value; Invalidate(); } }
    public int Maximum { get { return _max; } set { _max = value; Invalidate(); } }
    public int Value {
        get { return _value; }
        set {
            int v = Math.Max(_min, Math.Min(_max, value));
            if (v != _value) { _value = v; if (ValueChanged != null) ValueChanged(this, EventArgs.Empty); Invalidate(); }
        }
    }
    public event EventHandler ValueChanged;

    public SimpleSlider() {
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint |
                 ControlStyles.AllPaintingInWmPaint | ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        Cursor    = Cursors.Hand;
        AuroraTimer.Tick += OnGlobalTick;
    }

    private void OnGlobalTick(object s, EventArgs e) { if (!IsDisposed) Invalidate(); }

    protected override void Dispose(bool disposing) {
        if (disposing) AuroraTimer.Tick -= OnGlobalTick;
        base.Dispose(disposing);
    }

    private int ThumbX {
        get {
            float ratio = (float)(_value - _min) / Math.Max(_max - _min, 1);
            return PAD + (int)(ratio * (Width - PAD * 2));
        }
    }

    private int ValueFromX(int x) {
        float ratio = (float)(x - PAD) / Math.Max(Width - PAD * 2, 1);
        return _min + (int)(ratio * (_max - _min));
    }

    protected override void OnMouseDown(MouseEventArgs e) {
        if (e.Button == MouseButtons.Left) { _drag = true; Value = ValueFromX(e.X); }
        base.OnMouseDown(e);
    }
    protected override void OnMouseMove(MouseEventArgs e) {
        if (_drag) Value = ValueFromX(e.X);
        base.OnMouseMove(e);
    }
    protected override void OnMouseUp(MouseEventArgs e) { _drag = false; base.OnMouseUp(e); }

    protected override void OnPaint(PaintEventArgs e) {
        var g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias;
        int W = Width, H = Height, tx = ThumbX;
        int trackY = H / 2 - 2;
        float pulse = (float)Math.Sin(AuroraTimer.Time * 4) * 0.22f + 0.78f;

        var ff = this.FindForm(); int theme = (ff != null && ff.Tag is int) ? (int)ff.Tag : 0;

        Color trackBg, trackFill1, trackFill2, thumbC1, thumbC2, thumbBorder;
        if (theme == 2) { // Jasny
            trackBg    = Color.FromArgb(80, 150, 150, 150);
            trackFill1 = Color.FromArgb(160, 90, 90, 90);
            trackFill2 = Color.FromArgb(230, 60, 60, 60);
            thumbC1    = Color.FromArgb((int)(180 * pulse), 90, 90, 90);
            thumbC2    = Color.FromArgb((int)(240 * pulse), 60, 60, 60);
            thumbBorder= Color.FromArgb((int)(240 * pulse), 70, 70, 70);
        } else if (theme == 1) { // Ciemny
            trackBg    = Color.FromArgb(55, 90, 90, 90);
            trackFill1 = Color.FromArgb(150, 140, 140, 140);
            trackFill2 = Color.FromArgb(230, 180, 180, 180);
            thumbC1    = Color.FromArgb((int)(160 * pulse), 130, 130, 130);
            thumbC2    = Color.FromArgb((int)(220 * pulse), 170, 170, 170);
            thumbBorder= Color.FromArgb((int)(230 * pulse), 160, 160, 160);
        } else if (theme == 3) { // Szkło (Matowy)
            trackBg    = Color.FromArgb(60, 80, 120, 160);
            trackFill1 = Color.FromArgb(160, 130, 180, 220);
            trackFill2 = Color.FromArgb(240, 160, 210, 255);
            thumbC1    = Color.FromArgb((int)(180 * pulse), 130, 180, 220);
            thumbC2    = Color.FromArgb((int)(240 * pulse), 180, 220, 255);
            thumbBorder= Color.FromArgb((int)(240 * pulse), 150, 200, 240);
        } else { // Aurora
            trackBg    = Color.FromArgb(40, 80, 200, 130);
            trackFill1 = Color.FromArgb(130, 60, 200, 130);
            trackFill2 = Color.FromArgb(220, 100, 255, 180);
            thumbC1    = Color.FromArgb((int)(145 * pulse), 70, 210, 145);
            thumbC2    = Color.FromArgb((int)(210 * pulse), 120, 255, 185);
            thumbBorder= Color.FromArgb((int)(225 * pulse), 120, 255, 190);
        }

        using (var tb = new SolidBrush(trackBg))
            g.FillRectangle(tb, PAD, trackY, W - PAD * 2, 4);

        if (tx > PAD) {
            using (var tf = new LinearGradientBrush(
                new Rectangle(PAD, trackY, W - PAD * 2, 4),
                trackFill1, trackFill2, LinearGradientMode.Horizontal))
                g.FillRectangle(tf, new Rectangle(PAD, trackY, tx - PAD, 4));
        }

        var thumbR = new Rectangle(tx - THUMB_R, H / 2 - THUMB_R, THUMB_R * 2, THUMB_R * 2);
        using (var tg2 = new LinearGradientBrush(thumbR, thumbC1, thumbC2, LinearGradientMode.Vertical))
            g.FillEllipse(tg2, thumbR);
        using (var tp = new Pen(thumbBorder, 1.5f))
            g.DrawEllipse(tp, thumbR);
    }
}

// ─── AppTile ─────────────────────────────────────────────────────────────────
public class AppTile : Control {
    public string AppName    { get; set; }
    public string AppPath    { get; set; }
    public Image  AppIcon    { get; set; }
    public bool   IsEditMode { get; set; }

    private bool  _hover       = false;
    private bool  _pressRemove = false;

    public event EventHandler RemoveRequested;
    private Rectangle RemoveRect { get { return new Rectangle(Width - 23, 3, 20, 20); } }

    private static GraphicsPath RoundPath(Rectangle r, int rad) {
        var p = new GraphicsPath(); int d = rad * 2;
        p.AddArc(r.X,          r.Y,          d, d, 180, 90);
        p.AddArc(r.Right - d,  r.Y,          d, d, 270, 90);
        p.AddArc(r.Right - d,  r.Bottom - d, d, d,   0, 90);
        p.AddArc(r.X,          r.Bottom - d, d, d,  90, 90);
        p.CloseFigure(); return p;
    }

    public AppTile() {
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint |
                 ControlStyles.AllPaintingInWmPaint | ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        Cursor    = Cursors.Hand;
        AuroraTimer.Tick += OnGlobalTick;
        MouseEnter += (s, ev) => { _hover = true;  Invalidate(); };
        MouseLeave += (s, ev) => { _hover = false; Invalidate(); };
        MouseDown  += (s, ev) => {
            var me = (MouseEventArgs)ev;
            if (me.Button == MouseButtons.Left && IsEditMode && RemoveRect.Contains(me.Location)) {
                _pressRemove = true; Invalidate();
            }
        };
        MouseUp += (s, ev) => {
            var me = (MouseEventArgs)ev;
            if (_pressRemove) {
                if (RemoveRect.Contains(me.Location) && RemoveRequested != null)
                    RemoveRequested(this, EventArgs.Empty);
                _pressRemove = false; Invalidate();
            }
        };
    }

    private void OnGlobalTick(object s, EventArgs e) { if (!IsDisposed) Invalidate(); }

    protected override void Dispose(bool disposing) {
        if (disposing) AuroraTimer.Tick -= OnGlobalTick;
        base.Dispose(disposing);
    }

    protected override void OnPaint(PaintEventArgs e) {
        var g = e.Graphics;
        g.SmoothingMode     = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        int W = Width, H = Height;
        var rect = new Rectangle(1, 1, W - 2, H - 2);
        var _ff = this.FindForm(); int theme = (_ff != null && _ff.Tag is int) ? (int)_ff.Tag : 0;

        Color bgColor, borderColor, textColor, glowColor;
        int   bgA;
        if (theme == 2) { // Jasny
            bgA       = _hover ? 220 : 180;
            bgColor   = Color.FromArgb(bgA, 250, 250, 250);
            borderColor = _hover ? Color.FromArgb(200, 100, 100, 100) : Color.FromArgb(120, 155, 155, 155);
            textColor   = Color.FromArgb(_hover ? 240 : 190, 45, 45, 45);
            glowColor   = Color.FromArgb(35, 120, 120, 120);
        } else if (theme == 1) { // Ciemny
            bgA       = _hover ? 210 : 160;
            bgColor   = Color.FromArgb(bgA, 48, 48, 48);
            borderColor = _hover ? Color.FromArgb(210, 110, 110, 110) : Color.FromArgb(140, 68, 68, 68);
            textColor   = Color.FromArgb(_hover ? 245 : 185, 195, 195, 195);
            glowColor   = Color.FromArgb(28, 100, 100, 100);
        } else if (theme == 3) { // Szkło (Matowy)
            bgA       = _hover ? 130 : 70;
            bgColor   = Color.FromArgb(bgA, 130, 180, 220);
            borderColor = _hover ? Color.FromArgb(170, 180, 220, 255) : Color.FromArgb(90, 120, 160, 200);
            textColor   = Color.FromArgb(_hover ? 255 : 220, 240, 245, 255);
            glowColor   = Color.FromArgb(30, 100, 180, 255);
        } else { // Aurora (domyślny)
            bgA       = _hover ? 78 : 55;
            bgColor   = Color.FromArgb(bgA, 10, 32, 20);
            borderColor = _hover
                ? Color.FromArgb((int)((float)Math.Sin(AuroraTimer.Time * 5) * 0.22f * 198 + 0.78f * 198), 88, 228, 160)
                : Color.FromArgb((int)((float)Math.Sin(AuroraTimer.Time * 5) * 0.22f * 140 + 0.78f * 140), 88, 228, 160);
            textColor   = Color.FromArgb(_hover ? 235 : 165, 108, 242, 170);
            glowColor   = Color.FromArgb((int)((float)Math.Sin(AuroraTimer.Time * 5) * 0.22f * 30 + 0.78f * 30), 100, 255, 175);
        }

        using (var path = RoundPath(rect, 10)) {
            using (var bg = new SolidBrush(bgColor))
                g.FillPath(bg, path);

            float borderW = _hover ? 1.5f : 1.0f;
            using (var bp = new Pen(borderColor, borderW))
                g.DrawPath(bp, path);

            if (_hover) {
                using (var ig = new LinearGradientBrush(rect, glowColor, Color.FromArgb(0, 0, 0, 0), LinearGradientMode.Vertical))
                    g.FillPath(ig, path);
            }

            int nameH    = 23;
            int iAreaH   = H - nameH - 8;
            int iconSize = (int)(Math.Min(W - 16, iAreaH) * 0.68f);
            int iconX    = (W - iconSize) / 2;
            int iconY    = (iAreaH - iconSize) / 2 + 5;

            if (AppIcon != null) {
                g.DrawImage(AppIcon, new Rectangle(iconX, iconY, iconSize, iconSize),
                    0, 0, AppIcon.Width, AppIcon.Height, GraphicsUnit.Pixel);
            } else {
                Color ph = (theme == 2) ? Color.FromArgb(80, 130, 130, 130) : Color.FromArgb(80, 90, 90, 90);
                using (var pb = new SolidBrush(ph))  g.FillEllipse(pb, iconX, iconY, iconSize, iconSize);
                using (var pp = new Pen(ph, 1))       g.DrawEllipse(pp, iconX, iconY, iconSize, iconSize);
            }

            using (var f  = new Font("Segoe UI", 7.5f))
            using (var tb = new SolidBrush(textColor)) {
                var sf = new StringFormat {
                    Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center,
                    Trimming  = StringTrimming.EllipsisCharacter
                };
                g.DrawString(AppName ?? "App", f, tb, new RectangleF(2, H - nameH, W - 4, nameH - 2), sf);
            }

            if (IsEditMode) {
                var rb = RemoveRect;
                int ox = (int)(Math.Sin(AuroraTimer.Time * 11) * 1.8);
                using (var rbg = new SolidBrush(Color.FromArgb(_pressRemove ? 175 : 112, 215, 45, 45)))
                    g.FillEllipse(rbg, rb.X + ox, rb.Y, rb.Width, rb.Height);
                using (var rbp = new Pen(Color.FromArgb(215, 255, 102, 102), 1f))
                    g.DrawEllipse(rbp, rb.X + ox, rb.Y, rb.Width, rb.Height);
                using (var rf  = new Font("Segoe UI", 8.5f, FontStyle.Bold))
                using (var rfb = new SolidBrush(Color.FromArgb(240, 255, 200, 200))) {
                    var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
                    g.DrawString("x", rf, rfb, new RectangleF(rb.X + ox, rb.Y, rb.Width, rb.Height), sf);
                }
            }
        }
    }
}

// ─── AuroraDeck (main form) ───────────────────────────────────────────────────
public class AuroraDeck : Form {
    public const string DECK_VER = "magnet_glass6";

    private Timer  _anim  = new Timer();
    private float  _time  = 0f;
    private const float TIME_LOOP = (float)(Math.PI * 20.0);

    private Bitmap _bgBmp     = null;
    private Size   _cachedSz  = Size.Empty;

    private float[] _starSX = null;
    private float[] _starSY = null;
    private float[] _starSS = null;

    private int ThemeNow { get { return (this.Tag is int) ? (int)this.Tag : 0; } }
    public void RebuildCachePublic() { RebuildCache(); }

    public  Rectangle closeRect   = Rectangle.Empty;
    private bool      _hoverClose = false;
    private bool      _pressClose = false;
    public  string    FormTitle   = "Aurora Deck  1.0";

    struct Band {
        public float H, Sp, Amp, Fr, Ph, Y, A;
        public Band(float h,float s,float a,float f,float p,float y,float al){
            H=h; Sp=s; Amp=a; Fr=f; Ph=p; Y=y; A=al;
        }
    }

    Band[] B = new Band[]{
        new Band(160,0.7f,0.22f,0.012f,0.0f,0.30f,0.18f),
        new Band(190,0.5f,0.18f,0.009f,1.2f,0.42f,0.15f),
        new Band(140,0.9f,0.16f,0.015f,2.4f,0.25f,0.13f),
        new Band(210,0.4f,0.22f,0.008f,3.6f,0.50f,0.15f),
        new Band(175,0.6f,0.18f,0.011f,0.8f,0.35f,0.11f),
        new Band(260,0.3f,0.26f,0.007f,4.5f,0.20f,0.10f),
    };

    public AuroraDeck() {
        FormBorderStyle = FormBorderStyle.None;
        BackColor       = Color.Black;
        AutoScaleMode   = AutoScaleMode.Dpi;
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint |
                 ControlStyles.AllPaintingInWmPaint | ControlStyles.ResizeRedraw, true);

        _anim.Interval = 16;
        _anim.Tick += (s, e) => {
            _time += 0.02f;
            if (_time >= TIME_LOOP) _time -= TIME_LOOP;
            if (!AnimPaused) Invalidate();
        };
        _anim.Start();

        MouseDown += (s, e) => {
            var me = (MouseEventArgs)e;
            if (me.Button == MouseButtons.Left && me.Y < 58 && !closeRect.Contains(me.Location)) {
                WinAPI.ReleaseCapture();
                WinAPI.SendMessage(Handle, WinAPI.WM_NCLBUTTONDOWN, (IntPtr)WinAPI.HTCAPTION, IntPtr.Zero);
            }
            if (me.Button == MouseButtons.Left && closeRect.Contains(me.Location)) {
                _pressClose = true; Invalidate(closeRect);
            }
        };
        MouseUp += (s, e) => {
            var me = (MouseEventArgs)e;
            if (_pressClose && closeRect.Contains(me.Location)) this.Close();
            _pressClose = false; Invalidate(closeRect);
        };
        MouseMove += (s, e) => {
            var me = (MouseEventArgs)e;
            bool h = closeRect.Contains(me.Location);
            if (h != _hoverClose) {
                _hoverClose = h; Cursor = _hoverClose ? Cursors.Hand : Cursors.Default;
                Invalidate(closeRect);
            }
        };
        Resize += (s, e) => { UpdateCloseRect(); RebuildCache(); };
        Load   += (s, e) => { UpdateCloseRect(); RebuildCache(); };
    }

    public bool AnimPaused = false;

    public void PauseAnim()  { AnimPaused = true; }
    public void ResumeAnim() { AnimPaused = false; Invalidate(); }

    private void RebuildCache() {
        int W = ClientSize.Width, H = ClientSize.Height;
        if (W <= 0 || H <= 0) return;

        if (_bgBmp != null) { _bgBmp.Dispose(); _bgBmp = null; }
        _bgBmp = new Bitmap(W, H, PixelFormat.Format32bppRgb);
        using (var g2 = Graphics.FromImage(_bgBmp)) {
            Color top, bot;
            if (ThemeNow == 1) {
                top = Color.FromArgb(26, 26, 26); bot = Color.FromArgb(34, 34, 34);
            } else if (ThemeNow == 2) {
                top = Color.FromArgb(245, 245, 245); bot = Color.FromArgb(232, 232, 232);
            } else if (ThemeNow == 3) {
                top = Color.FromArgb(30, 45, 60); bot = Color.FromArgb(10, 20, 30);
            } else {
                top = Color.FromArgb(3, 8, 16); bot = Color.FromArgb(8, 14, 28);
            }
            using (var sky = new LinearGradientBrush(new Rectangle(0,0,W,H), top, bot, LinearGradientMode.Vertical))
                g2.FillRectangle(sky, 0, 0, W, H);
        }

        _starSX = new float[100]; _starSY = new float[100]; _starSS = new float[100];
        for (int i = 0; i < 100; i++) {
            _starSX[i] = (float)((Math.Sin(i*127.1+42)*0.5+0.5)*W);
            _starSY[i] = (float)((Math.Sin(i*311.7+42)*0.5+0.5)*H*0.7f);
            _starSS[i] = (float)((Math.Sin(i*73.3 )*0.5+0.5)*1.7f+0.3f);
        }
        _cachedSz = ClientSize;
    }

    protected override void Dispose(bool disposing) {
        if (disposing) { _anim.Dispose(); if (_bgBmp != null) _bgBmp.Dispose(); }
        base.Dispose(disposing);
    }

    private void UpdateCloseRect() {
        closeRect = new Rectangle(ClientSize.Width - 48, 12, 32, 32);
    }

    static Color HSL(float h,float s,float l,float a){
        h%=360; if(h<0)h+=360;
        float c=(1-Math.Abs(2*l-1))*s, x=c*(1-Math.Abs((h/60)%2-1)), m=l-c/2;
        float r=0,g=0,b=0;
        if(h<60){r=c;g=x;}else if(h<120){r=x;g=c;}else if(h<180){g=c;b=x;}
        else if(h<240){g=x;b=c;}else if(h<300){r=x;b=c;}else{r=c;b=x;}
        return Color.FromArgb((int)(a*255),(int)((r+m)*255),(int)((g+m)*255),(int)((b+m)*255));
    }

    protected override void OnPaint(PaintEventArgs e) {
        var g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias;
        int W = Width, H = Height;

        if (ThemeNow == 0) {
            // ── AURORA ───────────────────────────────────────────────────────
            if (_bgBmp != null && _cachedSz == ClientSize) g.DrawImage(_bgBmp, 0, 0);
            if (_starSX != null) {
                for (int i = 0; i < 100; i++) {
                    float a  = (float)(Math.Sin(_time*1.5+i*0.4)*0.3+0.7);
                    float ss = _starSS[i];
                    using (var b = new SolidBrush(Color.FromArgb((int)(a*180),220,230,255)))
                        g.FillEllipse(b, _starSX[i]-ss/2, _starSY[i]-ss/2, ss, ss);
                }
            }
            foreach(var v in B){
                int S=60; PointF[] pts=new PointF[S+3]; pts[0]=new PointF(0,H);
                float minY=H;
                for(int i=0;i<=S;i++){
                    float x=(float)i/S*W;
                    float y=H*v.Y+(float)Math.Sin(_time*v.Sp+i*v.Fr*6+v.Ph)*H*v.Amp
                                 +(float)Math.Sin(_time*v.Sp*2.0f+i*v.Fr*10+v.Ph+1)*H*v.Amp*0.4f;
                    pts[i+1]=new PointF(x,y); if(y<minY)minY=y;
                }
                pts[S+2]=new PointF(W,H);
                float hue=v.H+(float)Math.Sin(_time*0.3)*15;
                float hgh=Math.Max(H*v.Amp*3,1f);
                using(var br=new LinearGradientBrush(new RectangleF(0,minY,W,hgh),
                    Color.Transparent,Color.Transparent,LinearGradientMode.Vertical)){
                    var cb=new ColorBlend(4);
                    cb.Positions=new float[]{0,0.15f,0.55f,1};
                    cb.Colors=new Color[]{Color.FromArgb(0,0,0,0),HSL(hue,0.9f,0.65f,v.A*1.2f),
                        HSL(hue,0.9f,0.55f,v.A),Color.FromArgb(0,0,0,0)};
                    br.InterpolationColors=cb; g.FillPolygon(br,pts);
                }
            }
            // Logo
            {
                float _lp   = (float)Math.Sin(_time * 3.5f) * 0.16f + 0.84f;
                float _lcx  = 27f, _lcy = 25f, _lr = 11f;
                float _lhue = 155f + (float)Math.Sin(_time * 0.3f) * 20f;
                using (var _lgb = new SolidBrush(Color.FromArgb((int)(40*_lp), 60, 220, 150)))
                    g.FillEllipse(_lgb, _lcx-_lr-3, _lcy-_lr-3, (_lr+3)*2, (_lr+3)*2);
                PointF[] _lhx = new PointF[6];
                for (int _li = 0; _li < 6; _li++) {
                    float _la = (float)(Math.PI/3.0*_li - Math.PI/6.0);
                    _lhx[_li] = new PointF(_lcx + _lr*(float)Math.Cos(_la), _lcy + _lr*(float)Math.Sin(_la));
                }
                using (var _lpath = new GraphicsPath()) {
                    _lpath.AddPolygon(_lhx);
                    using (var _lfill = new SolidBrush(Color.FromArgb((int)(25*_lp), 50, 190, 130)))
                        g.FillPath(_lfill, _lpath);
                    using (var _lpen = new Pen(HSL(_lhue, 0.85f, 0.62f, _lp*0.9f), 1.5f))
                        g.DrawPath(_lpen, _lpath);
                    g.SetClip(_lpath);
                    for (int _li = 0; _li < 3; _li++) {
                        float _laY = _lcy - 5f + _li*5f;
                        float _laH = _lhue + _li*28f;
                        float _laA = (float)Math.Sin(_time*2.1f + _li*0.8f)*0.22f + 0.75f;
                        PointF[] _lwp = new PointF[8];
                        for (int _lj = 0; _lj < 8; _lj++) {
                            float _lt2 = (float)_lj/7f;
                            float _lwx = (_lcx-_lr+2) + _lt2*((_lcx+_lr-2)-(_lcx-_lr+2));
                            float _lwy = _laY + (float)Math.Sin(_time*1.5f+_li*1.5f+_lwx*0.32f)*2.5f;
                            _lwp[_lj] = new PointF(_lwx, _lwy);
                        }
                        using (var _lw = new Pen(HSL(_laH, 0.9f, 0.68f, _laA*_lp), 1.8f)) {
                            _lw.StartCap = System.Drawing.Drawing2D.LineCap.Round;
                            _lw.EndCap   = System.Drawing.Drawing2D.LineCap.Round;
                            g.DrawLines(_lw, _lwp);
                        }
                    }
                    g.ResetClip();
                }
            }
            using(var f=new Font("Segoe UI",11,FontStyle.Bold))
            using(var br=new SolidBrush(Color.FromArgb(200,200,230)))
                g.DrawString(FormTitle,f,br,48,16);
            using(var lp=new Pen(Color.FromArgb(38,100,255,180),1))
                g.DrawLine(lp,0,56,W,56);
            var R0=closeRect;
            int fA0=_pressClose?80:(_hoverClose?60:40), bA0=_pressClose?160:(_hoverClose?120:90);
            using(var p=new Pen(Color.FromArgb(bA0,255,150,140)))
            using(var pb=new SolidBrush(Color.FromArgb(fA0,255,120,100))){ g.FillRectangle(pb,R0); g.DrawRectangle(p,R0); }
            using(var f=new Font("Segoe UI",14f))
            using(var br=new SolidBrush(Color.FromArgb(220,255,200,190))){
                var sz=g.MeasureString("x",f);
                g.DrawString("x",f,br,R0.X+(R0.Width-sz.Width)/2,R0.Y+(R0.Height-sz.Height)/2-1);
            }

        } else if (ThemeNow == 1) {
            // ── CIEMNY ───────────────────────────────────────────────────────
            if (_bgBmp != null && _cachedSz == ClientSize) g.DrawImage(_bgBmp, 0, 0);
            {
                float _lp   = (float)Math.Sin(_time * 3.5f) * 0.16f + 0.84f;
                float _lcx  = 27f, _lcy = 25f, _lr = 11f;
                float _lhue = 155f + (float)Math.Sin(_time * 0.3f) * 20f;
                using (var _lgb = new SolidBrush(Color.FromArgb((int)(40*_lp), 60, 220, 150)))
                    g.FillEllipse(_lgb, _lcx-_lr-3, _lcy-_lr-3, (_lr+3)*2, (_lr+3)*2);
                PointF[] _lhx = new PointF[6];
                for (int _li = 0; _li < 6; _li++) {
                    float _la = (float)(Math.PI/3.0*_li - Math.PI/6.0);
                    _lhx[_li] = new PointF(_lcx + _lr*(float)Math.Cos(_la), _lcy + _lr*(float)Math.Sin(_la));
                }
                using (var _lpath = new GraphicsPath()) {
                    _lpath.AddPolygon(_lhx);
                    using (var _lfill = new SolidBrush(Color.FromArgb((int)(25*_lp), 50, 190, 130)))
                        g.FillPath(_lfill, _lpath);
                    using (var _lpen = new Pen(HSL(_lhue, 0.85f, 0.62f, _lp*0.9f), 1.5f))
                        g.DrawPath(_lpen, _lpath);
                    g.SetClip(_lpath);
                    for (int _li = 0; _li < 3; _li++) {
                        float _laY = _lcy - 5f + _li*5f;
                        float _laH = _lhue + _li*28f;
                        float _laA = (float)Math.Sin(_time*2.1f + _li*0.8f)*0.22f + 0.75f;
                        PointF[] _lwp = new PointF[8];
                        for (int _lj = 0; _lj < 8; _lj++) {
                            float _lt2 = (float)_lj/7f;
                            float _lwx = (_lcx-_lr+2) + _lt2*((_lcx+_lr-2)-(_lcx-_lr+2));
                            float _lwy = _laY + (float)Math.Sin(_time*1.5f+_li*1.5f+_lwx*0.32f)*2.5f;
                            _lwp[_lj] = new PointF(_lwx, _lwy);
                        }
                        using (var _lw = new Pen(HSL(_laH, 0.9f, 0.68f, _laA*_lp), 1.8f)) {
                            _lw.StartCap = System.Drawing.Drawing2D.LineCap.Round;
                            _lw.EndCap   = System.Drawing.Drawing2D.LineCap.Round;
                            g.DrawLines(_lw, _lwp);
                        }
                    }
                    g.ResetClip();
                }
            }
            using(var f=new Font("Segoe UI",11,FontStyle.Bold))
            using(var br=new SolidBrush(Color.FromArgb(210,195,195,195)))
                g.DrawString(FormTitle,f,br,48,16);
            using(var lp=new Pen(Color.FromArgb(70, 80, 80, 80),1))
                g.DrawLine(lp,0,56,W,56);
            var R1=closeRect;
            int fA1=_pressClose?85:(_hoverClose?58:34), bA1=_pressClose?165:(_hoverClose?125:78);
            using(var p=new Pen(Color.FromArgb(bA1,180,100,100)))
            using(var pb=new SolidBrush(Color.FromArgb(fA1,155,70,70))){ g.FillRectangle(pb,R1); g.DrawRectangle(p,R1); }
            using(var f=new Font("Segoe UI",14f))
            using(var br=new SolidBrush(Color.FromArgb(220,235,210,210))){
                var sz=g.MeasureString("x",f);
                g.DrawString("x",f,br,R1.X+(R1.Width-sz.Width)/2,R1.Y+(R1.Height-sz.Height)/2-1);
            }

        } else if (ThemeNow == 2) {
            // ── JASNY ────────────────────────────────────────────────────────
            if (_bgBmp != null && _cachedSz == ClientSize) g.DrawImage(_bgBmp, 0, 0);
            {
                float _lp   = (float)Math.Sin(_time * 3.5f) * 0.16f + 0.84f;
                float _lcx  = 27f, _lcy = 25f, _lr = 11f;
                float _lhue = 155f + (float)Math.Sin(_time * 0.3f) * 20f;
                using (var _lgb = new SolidBrush(Color.FromArgb((int)(40*_lp), 60, 220, 150)))
                    g.FillEllipse(_lgb, _lcx-_lr-3, _lcy-_lr-3, (_lr+3)*2, (_lr+3)*2);
                PointF[] _lhx = new PointF[6];
                for (int _li = 0; _li < 6; _li++) {
                    float _la = (float)(Math.PI/3.0*_li - Math.PI/6.0);
                    _lhx[_li] = new PointF(_lcx + _lr*(float)Math.Cos(_la), _lcy + _lr*(float)Math.Sin(_la));
                }
                using (var _lpath = new GraphicsPath()) {
                    _lpath.AddPolygon(_lhx);
                    using (var _lfill = new SolidBrush(Color.FromArgb((int)(25*_lp), 50, 190, 130)))
                        g.FillPath(_lfill, _lpath);
                    using (var _lpen = new Pen(HSL(_lhue, 0.85f, 0.62f, _lp*0.9f), 1.5f))
                        g.DrawPath(_lpen, _lpath);
                    g.SetClip(_lpath);
                    for (int _li = 0; _li < 3; _li++) {
                        float _laY = _lcy - 5f + _li*5f;
                        float _laH = _lhue + _li*28f;
                        float _laA = (float)Math.Sin(_time*2.1f + _li*0.8f)*0.22f + 0.75f;
                        PointF[] _lwp = new PointF[8];
                        for (int _lj = 0; _lj < 8; _lj++) {
                            float _lt2 = (float)_lj/7f;
                            float _lwx = (_lcx-_lr+2) + _lt2*((_lcx+_lr-2)-(_lcx-_lr+2));
                            float _lwy = _laY + (float)Math.Sin(_time*1.5f+_li*1.5f+_lwx*0.32f)*2.5f;
                            _lwp[_lj] = new PointF(_lwx, _lwy);
                        }
                        using (var _lw = new Pen(HSL(_laH, 0.9f, 0.68f, _laA*_lp), 1.8f)) {
                            _lw.StartCap = System.Drawing.Drawing2D.LineCap.Round;
                            _lw.EndCap   = System.Drawing.Drawing2D.LineCap.Round;
                            g.DrawLines(_lw, _lwp);
                        }
                    }
                    g.ResetClip();
                }
            }
            using(var f=new Font("Segoe UI",11,FontStyle.Bold))
            using(var br=new SolidBrush(Color.FromArgb(230, 50, 50, 50)))
                g.DrawString(FormTitle,f,br,48,16);
            using(var lp=new Pen(Color.FromArgb(100, 160,160,160),1))
                g.DrawLine(lp,0,56,W,56);
            var R2=closeRect;
            int fA2=_pressClose?100:(_hoverClose?72:46), bA2=_pressClose?210:(_hoverClose?160:110);
            using(var p=new Pen(Color.FromArgb(bA2,200,65,65)))
            using(var pb=new SolidBrush(Color.FromArgb(fA2,200,65,65))){ g.FillRectangle(pb,R2); g.DrawRectangle(p,R2); }
            using(var f=new Font("Segoe UI",14f))
            using(var br=new SolidBrush(Color.FromArgb(240,255,255,255))){
                var sz=g.MeasureString("x",f);
                g.DrawString("x",f,br,R2.X+(R2.Width-sz.Width)/2,R2.Y+(R2.Height-sz.Height)/2-1);
            }

        } else if (ThemeNow == 3) {
            // ── MATOWY (Szkło) ──────────────────────────────
            if (_bgBmp != null && _cachedSz == ClientSize) g.DrawImage(_bgBmp, 0, 0);
            {
                float _lp   = (float)Math.Sin(_time * 3.5f) * 0.16f + 0.84f;
                float _lcx  = 27f, _lcy = 25f, _lr = 11f;
                float _lhue = 155f + (float)Math.Sin(_time * 0.3f) * 20f;
                using (var _lgb = new SolidBrush(Color.FromArgb((int)(40*_lp), 60, 220, 150)))
                    g.FillEllipse(_lgb, _lcx-_lr-3, _lcy-_lr-3, (_lr+3)*2, (_lr+3)*2);
                PointF[] _lhx = new PointF[6];
                for (int _li = 0; _li < 6; _li++) {
                    float _la = (float)(Math.PI/3.0*_li - Math.PI/6.0);
                    _lhx[_li] = new PointF(_lcx + _lr*(float)Math.Cos(_la), _lcy + _lr*(float)Math.Sin(_la));
                }
                using (var _lpath = new GraphicsPath()) {
                    _lpath.AddPolygon(_lhx);
                    using (var _lfill = new SolidBrush(Color.FromArgb((int)(25*_lp), 50, 190, 130)))
                        g.FillPath(_lfill, _lpath);
                    using (var _lpen = new Pen(HSL(_lhue, 0.85f, 0.62f, _lp*0.9f), 1.5f))
                        g.DrawPath(_lpen, _lpath);
                    g.SetClip(_lpath);
                    for (int _li = 0; _li < 3; _li++) {
                        float _laY = _lcy - 5f + _li*5f;
                        float _laH = _lhue + _li*28f;
                        float _laA = (float)Math.Sin(_time*2.1f + _li*0.8f)*0.22f + 0.75f;
                        PointF[] _lwp = new PointF[8];
                        for (int _lj = 0; _lj < 8; _lj++) {
                            float _lt2 = (float)_lj/7f;
                            float _lwx = (_lcx-_lr+2) + _lt2*((_lcx+_lr-2)-(_lcx-_lr+2));
                            float _lwy = _laY + (float)Math.Sin(_time*1.5f+_li*1.5f+_lwx*0.32f)*2.5f;
                            _lwp[_lj] = new PointF(_lwx, _lwy);
                        }
                        using (var _lw = new Pen(HSL(_laH, 0.9f, 0.68f, _laA*_lp), 1.8f)) {
                            _lw.StartCap = System.Drawing.Drawing2D.LineCap.Round;
                            _lw.EndCap   = System.Drawing.Drawing2D.LineCap.Round;
                            g.DrawLines(_lw, _lwp);
                        }
                    }
                    g.ResetClip();
                }
            }
            using(var f=new Font("Segoe UI",11,FontStyle.Bold))
            using(var br=new SolidBrush(Color.FromArgb(230,240,255)))
                g.DrawString(FormTitle,f,br,48,16);
            using(var lp=new Pen(Color.FromArgb(60, 150, 200, 255),1))
                g.DrawLine(lp,0,56,W,56);
            var R3=closeRect;
            int fA3=_pressClose?90:(_hoverClose?60:30), bA3=_pressClose?180:(_hoverClose?140:80);
            using(var p=new Pen(Color.FromArgb(bA3,200,100,100)))
            using(var pb=new SolidBrush(Color.FromArgb(fA3,180,70,70))){ g.FillRectangle(pb,R3); g.DrawRectangle(p,R3); }
            using(var f=new Font("Segoe UI",14f))
            using(var br=new SolidBrush(Color.FromArgb(220,255,255,255))){
                var sz=g.MeasureString("x",f);
                g.DrawString("x",f,br,R3.X+(R3.Width-sz.Width)/2,R3.Y+(R3.Height-sz.Height)/2-1);
            }
        }
    }
}
"@ -ReferencedAssemblies "System.Windows.Forms","System.Drawing"
} catch { <# typ juz istnieje w tej sesji — uzywamy skompilowanej wersji #> }
} # end if needsCompile

# ===========================================================
#   Sciezki i konfiguracja
# ===========================================================

$script:scriptDir  = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:dataFile = Join-Path $script:scriptDir "aurora.json"
$script:iconDir  = Join-Path $script:scriptDir "deck_icons"

if (-not (Test-Path $script:iconDir)) {
    New-Item -ItemType Directory -Path $script:iconDir | Out-Null
}

# ===========================================================
#   Zmienne globalne stanu
# ===========================================================

$script:tileSize      = 110
$script:isUnlocked    = $false
$script:isEditMode    = $false
$script:currentFolder    = "Dashboard" # Domyślnie ładujemy Stronę Główną
$script:sidebarWidth     = 140
$script:sidebarPanel     = $null
$script:folderMap        = @{}
$script:unlockedFolders  = @{}

# ─── Drag & drop kafli (tryb edycji) ──────────────────────────
$script:dragTile        = $null
$script:dragGhost       = $null
$script:dragOffset      = $null
$script:dragStartScreen = $null

# ===========================================================
#   Funkcje pomocnicze
# ===========================================================

function Enable-DoubleBuffer {
    param($ctrl)
    try {
        $prop = $ctrl.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
        if ($prop) { $prop.SetValue($ctrl, $true, $null) }
    } catch {}
}

function Read-AuroraData {
    if (Test-Path $script:dataFile) {
        try {
            $raw = Get-Content $script:dataFile -Raw -Encoding UTF8
            return $raw | ConvertFrom-Json
        } catch {}
    }
    return [PSCustomObject]@{
        settings = [PSCustomObject]@{ TileSize = 110; City = "" }
        folders  = @()
        apps     = @()
    }
}

function Write-AuroraData {
    param($data)
    $data | ConvertTo-Json -Depth 6 | Set-Content -Path $script:dataFile -Encoding UTF8
}

function Get-AppConfig {
    $d = Read-AuroraData
    $arr = if ($d.apps -is [array]) { $d.apps } elseif ($d.apps) { @($d.apps) } else { @() }
    return $arr
}

function Save-AppConfig {
    param([object[]]$entries)
    $d = Read-AuroraData
    $d | Add-Member -NotePropertyName apps -NotePropertyValue @($entries) -Force
    Write-AuroraData $d
}

function Increment-AppLaunchCount {
    param([string]$path)
    $absPath = ConvertTo-AbsolutePath $path
    $apps = @(Get-AppConfig)
    $changed = $false
    foreach ($a in $apps) {
        if ((ConvertTo-AbsolutePath $a.Path) -eq $absPath) {
            if (-not $a.LaunchCount) { $a | Add-Member -NotePropertyName LaunchCount -NotePropertyValue 0 -Force }
            $a.LaunchCount++
            $changed = $true
        }
    }
    if ($changed) { 
        Save-AppConfig -entries $apps
        if ((Get-Command Refresh-DashboardTopApps -ErrorAction SilentlyContinue)) { Refresh-DashboardTopApps }
    }
}

function Get-Settings {
    $d = Read-AuroraData
    if ($d.settings) { return $d.settings }
    return [PSCustomObject]@{ TileSize = 110; City = "" }
}

function Save-Settings {
    param([int]$tileSize, [int]$theme = -1, [string]$city = "")
    $d = Read-AuroraData
    if (-not $d.settings) { $d | Add-Member -NotePropertyName settings -NotePropertyValue ([PSCustomObject]@{}) -Force }
    $d.settings | Add-Member -NotePropertyName TileSize -NotePropertyValue $tileSize -Force
    if ($theme -ge 0) { $d.settings | Add-Member -NotePropertyName Theme -NotePropertyValue $theme -Force }
    if ($city -ne $null) { $d.settings | Add-Member -NotePropertyName City -NotePropertyValue $city -Force }
    Write-AuroraData $d
}

$script:tileSize = (Get-Settings).TileSize
$_savedTheme = (Get-Settings).Theme
if ($null -ne $_savedTheme -and $_savedTheme -ge 0 -and $_savedTheme -le 3) {
    $script:currentTheme = [int]$_savedTheme
}

function Get-SHA256Hash {
    param([string]$text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $hash  = $sha.ComputeHash($bytes)
    $sha.Dispose()
    return ([System.BitConverter]::ToString($hash) -replace '-','').ToLower()
}

function Get-FolderObjects {
    $d = Read-AuroraData
    $arr = if ($d.folders -is [array]) { $d.folders } elseif ($d.folders) { @($d.folders) } else { @() }
    $result = @()
    foreach ($item in $arr) {
        if ($item -is [string]) { $result += [PSCustomObject]@{ Name = $item; PasswordHash = "" } }
        else                    { $result += $item }
    }
    return $result
}

function Save-FolderObjects {
    param($folderObjects)
    $d = Read-AuroraData
    $arr = if ($folderObjects) { @($folderObjects) } else { @() }
    $d | Add-Member -NotePropertyName folders -NotePropertyValue $arr -Force
    Write-AuroraData $d
}

function Get-FolderList {
    return @(Get-FolderObjects | ForEach-Object { $_.Name })
}

function Save-FolderList {
    param([string[]]$folders)
    $existing = @(Get-FolderObjects)
    $newObjs  = @()
    foreach ($fn in $folders) {
        $old = $existing | Where-Object { $_.Name -eq $fn } | Select-Object -First 1
        if ($old) { $newObjs += $old }
        else       { $newObjs += [PSCustomObject]@{ Name = $fn; PasswordHash = "" } }
    }
    Save-FolderObjects -folderObjects $newObjs
}

function Get-FolderPasswordHash {
    param([string]$folderName)
    $obj = Get-FolderObjects | Where-Object { $_.Name -eq $folderName } | Select-Object -First 1
    if ($obj) { return $obj.PasswordHash } else { return "" }
}

function Set-FolderPasswordHash {
    param([string]$folderName, [string]$hash)
    $objs = @(Get-FolderObjects)
    foreach ($o in $objs) {
        if ($o.Name -eq $folderName) {
            $o | Add-Member -NotePropertyName PasswordHash -NotePropertyValue $hash -Force
        }
    }
    Save-FolderObjects -folderObjects $objs
}

function ConvertTo-StoredPath {
    param([string]$path)
    if (-not $path) { return $path }
    try {
        $abs  = [System.IO.Path]::GetFullPath($path)
        $base = [System.IO.Path]::GetFullPath($script:scriptDir)
        $sep  = [System.IO.Path]::DirectorySeparatorChar
        if ($abs.StartsWith($base + $sep, [System.StringComparison]::OrdinalIgnoreCase) -or
            $abs.Equals($base, [System.StringComparison]::OrdinalIgnoreCase)) {
            return '.' + $abs.Substring($base.Length)
        }
    } catch {}
    return $path
}

function ConvertTo-AbsolutePath {
    param([string]$path)
    if (-not $path) { return $path }
    try {
        if ($path.StartsWith('.\') -or $path.StartsWith('./') -or
            (-not [System.IO.Path]::IsPathRooted($path))) {
            return [System.IO.Path]::GetFullPath(
                [System.IO.Path]::Combine($script:scriptDir, $path))
        }
    } catch {}
    return $path
}

function Get-LnkTarget {
    param([string]$lnkPath)
    try {
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($lnkPath)
        return $sc.TargetPath
    } catch { return $null }
}

function Get-LnkIcon {
    param([string]$lnkPath)
    try {
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($lnkPath)
        if ($sc.IconLocation -and $sc.IconLocation -ne ',0') {
            $parts = $sc.IconLocation -split ','
            $iconSrc = $parts[0].Trim()
            if ($iconSrc -and (Test-Path $iconSrc)) { return $iconSrc }
        }
        return $sc.TargetPath
    } catch { return $null }
}

function Extract-AppIcon {
    param([string]$sourcePath, [string]$appName)
    if (-not $sourcePath) { return $null }

    $safeName = ($appName -replace '[\\/:*?"<>|]', '_').Trim()
    $iconPath = Join-Path $script:iconDir "$safeName.png"

    if (Test-Path $iconPath) { return $iconPath }

    try {
        if (-not (Test-Path $sourcePath)) { return $null }
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($sourcePath)
        if ($icon) {
            $srcBmp = $icon.ToBitmap()
            $srcBmp.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $srcBmp.Dispose()
            $icon.Dispose()
            return $iconPath
        }
    } catch {}
    return $null
}

# ===========================================================
#   Przebudowa kafli
# ===========================================================

function Rebuild-Tiles {
    $old = @($form.Controls | Where-Object { $_ -is [AppTile] })
    foreach ($t in $old) {
        if ($t.AppIcon) { try { $t.AppIcon.Dispose() } catch {} }
        $form.Controls.Remove($t)
        $t.Dispose()
    }
    $script:folderMap = @{}
    $savedApps = Get-AppConfig
    foreach ($entry in $savedApps) {
        if ($entry.Path) {
            $tile = New-TileControl $entry
            $form.Controls.Add($tile)
        }
    }
    Invoke-TileLayout
}

function End-TileDrag {
    param([System.Drawing.Point]$dropPoint)

    try {
        if (-not $script:dragTile) { return }
        $dragPath = $script:dragTile.Tag

        $gap    = 6
        $size   = $script:tileSize
        $startY = 72
        $sidebarEdge = if ($script:sidebarPanel) { $script:sidebarPanel.Left + $script:sidebarWidth } else { $script:sidebarWidth }
        $startX = [Math]::Max(11, $sidebarEdge + 11)
        $formW  = $form.ClientSize.Width
        $availW = $formW - $startX - 10
        $cols   = [Math]::Max(1, [Math]::Floor($availW / ($size + $gap)))

        $visibles = @($form.Controls | Where-Object { ($_ -is [AppTile]) -and $_.Visible })
        if ($visibles.Count -eq 0) { return }

        $col = [Math]::Floor(($dropPoint.X - $startX) / ($size + $gap))
        $row = [Math]::Floor(($dropPoint.Y - $startY) / ($size + $gap))
        $col = [Math]::Max(0, [Math]::Min($col, $cols - 1))
        $row = [Math]::Max(0, $row)
        $newIdx = [Math]::Min($row * $cols + $col, $visibles.Count - 1)
        $newIdx = [Math]::Max(0, $newIdx)

        $oldIdx = -1
        for ($i = 0; $i -lt $visibles.Count; $i++) {
            if ($visibles[$i].Tag -eq $dragPath) { $oldIdx = $i; break }
        }

        if ($oldIdx -ge 0 -and $oldIdx -ne $newIdx) {
            $apps = @(Get-AppConfig)
            $appDict = @{}
            foreach ($a in $apps) { $appDict[(ConvertTo-AbsolutePath $a.Path)] = $a }

            $vPaths = [System.Collections.Generic.List[string]]::new()
            foreach ($v in $visibles) { $vPaths.Add($v.Tag) }
            $vPaths.RemoveAt($oldIdx)
            $vPaths.Insert($newIdx, $dragPath)

            if ($script:currentFolder -eq "Wszystkie") {
                $newApps = @($vPaths | ForEach-Object { $appDict[$_] } | Where-Object { $_ -ne $null })
                foreach ($a in $apps) {
                    $absA = ConvertTo-AbsolutePath $a.Path
                    $already = $newApps | Where-Object { (ConvertTo-AbsolutePath $_.Path) -eq $absA }
                    if (-not $already) { $newApps += $a }
                }
                Save-AppConfig -entries $newApps
            } else {
                $oldFolderPaths = @($apps | Where-Object { $_.Folder -eq $script:currentFolder } | ForEach-Object { ConvertTo-AbsolutePath $_.Path })
                $newFolderApps  = @($vPaths | ForEach-Object { $appDict[$_] } | Where-Object { $_ -ne $null })
                $newApps = @(); $fi = 0
                foreach ($a in $apps) {
                    if ($oldFolderPaths -contains (ConvertTo-AbsolutePath $a.Path)) {
                        if ($fi -lt $newFolderApps.Count) { $newApps += $newFolderApps[$fi]; $fi++ }
                    } else { $newApps += $a }
                }
                Save-AppConfig -entries $newApps
            }
            Rebuild-Tiles
        }
    } finally {
        if ($script:dragGhost) {
            try { $form.Controls.Remove($script:dragGhost); $script:dragGhost.Dispose() } catch {}
            $script:dragGhost = $null
        }
        $script:dragTile        = $null
        $script:dragStartScreen = $null
        try { if ($form) { $form.Capture = $false } } catch {}
    }
}

function Move-FolderUp {
    param([string]$folderName)
    $list = @(Get-FolderList)
    $idx  = [array]::IndexOf($list, $folderName)
    if ($idx -le 0) { return }
    $tmp = $list[$idx - 1]; $list[$idx - 1] = $list[$idx]; $list[$idx] = $tmp
    Save-FolderList -folders $list
    Rebuild-FolderPanel
}

function Move-FolderDown {
    param([string]$folderName)
    $list = @(Get-FolderList)
    $idx  = [array]::IndexOf($list, $folderName)
    if ($idx -lt 0 -or $idx -ge ($list.Count - 1)) { return }
    $tmp = $list[$idx + 1]; $list[$idx + 1] = $list[$idx]; $list[$idx] = $tmp
    Save-FolderList -folders $list
    Rebuild-FolderPanel
}

function New-TileControl {
    param([PSCustomObject]$entry)

    $resolvedPath = ConvertTo-AbsolutePath $entry.Path
    $resolvedIcon = ConvertTo-AbsolutePath $entry.IconFile

    $tile          = New-Object AppTile
    $tile.AppName  = $entry.Name
    $tile.AppPath  = $resolvedPath
    $tile.Tag      = $resolvedPath
    $tile.Size     = New-Object System.Drawing.Size($script:tileSize, $script:tileSize)
    $tile.IsEditMode    = $script:isEditMode
    $script:folderMap[$resolvedPath] = if ($entry.Folder) { $entry.Folder } else { "" }

    if ($resolvedIcon -and (Test-Path $resolvedIcon)) {
        try {
            $rb  = [System.IO.File]::ReadAllBytes($resolvedIcon)
            $rms = New-Object System.IO.MemoryStream($rb, 0, $rb.Length)
            $img = [System.Drawing.Image]::FromStream($rms)
            $tile.AppIcon = New-Object System.Drawing.Bitmap($img)
            $img.Dispose()
            $rms.Dispose()
        } catch {}
    }

    $tile.Add_Click({
        param($s, $e)
        if ($s.IsEditMode) { return }
        $path = $s.Tag
        try { 
            Start-Process $path 
            Increment-AppLaunchCount -path $path
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Nie mozna uruchomic:`n$path", "Blad uruchamiania", 'OK', 'Warning')
        }
    })

    $tile.add_RemoveRequested({
        param($s, $e)
        Remove-AppEntry -AppPath $s.Tag
    })

    $tile.Add_MouseDown({
        param($s, $e)
        $me = [System.Windows.Forms.MouseEventArgs]$e
        if (-not $s.IsEditMode) { return }
        if ($me.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $removeRect = New-Object System.Drawing.Rectangle(($s.Width - 23), 3, 20, 20)
        if ($removeRect.Contains($me.Location)) { return }
        $script:dragTile        = $s
        $script:dragOffset      = $me.Location
        $script:dragStartScreen = $s.PointToScreen($me.Location)
        $s.Capture              = $true
    })

    $tile.Add_MouseMove({
        param($s, $e)
        if ($null -eq $script:dragTile -or $script:dragTile -ne $s) { return }
        $me = [System.Windows.Forms.MouseEventArgs]$e
        $curScreen = $s.PointToScreen($me.Location)

        if ($null -eq $script:dragGhost) {
            $dx = $curScreen.X - $script:dragStartScreen.X
            $dy = $curScreen.Y - $script:dragStartScreen.Y
            if ([Math]::Sqrt($dx*$dx + $dy*$dy) -lt 5) { return }

            $ghost = New-Object System.Windows.Forms.Panel
            $ghost.Size        = $s.Size
            $ghost.BackColor   = [System.Drawing.Color]::FromArgb(8, 18, 32)
            $ghost.BorderStyle = 'None'
            $ghost.Enabled     = $false
            $tileOnForm = $form.PointToClient($s.PointToScreen([System.Drawing.Point]::new(0,0)))
            $ghost.Location    = $tileOnForm
            $script:dragGhost  = $ghost
            $ghost.Add_Paint({
                param($gS, $gE)
                $gG = $gE.Graphics; $gG.SmoothingMode = 'AntiAlias'
                $gW = $gS.Width; $gH = $gS.Height
                $gBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 6, 22, 14))
                $gG.FillRectangle($gBg, 0, 0, $gW, $gH); $gBg.Dispose()
                $gDp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 80, 255, 150), 2)
                $gDp.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
                $gG.DrawRectangle($gDp, 2, 2, ($gW - 4), ($gH - 4)); $gDp.Dispose()
                if ($script:dragTile -and $script:dragTile.AppIcon) {
                    $iSz = [int]($gW * 0.52); $iX = ($gW - $iSz) / 2; $iY = ($gH - $iSz) / 2 - 5
                    $gG.DrawImage($script:dragTile.AppIcon, $iX, $iY, $iSz, $iSz)
                }
                if ($script:dragTile) {
                    $gSf = New-Object System.Drawing.StringFormat
                    $gSf.Alignment = 'Center'; $gSf.LineAlignment = 'Far'
                    $gSf.Trimming  = 'EllipsisCharacter'
                    $gF  = New-Object System.Drawing.Font('Segoe UI', 7.5)
                    $gBr = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 100, 235, 160))
                    $gG.DrawString($script:dragTile.AppName, $gF, $gBr,
                        [System.Drawing.RectangleF]::new(2, 0, ($gW - 4), ($gH - 3)), $gSf)
                    $gF.Dispose(); $gBr.Dispose(); $gSf.Dispose()
                }
            })
            $form.Controls.Add($ghost)
            $ghost.BringToFront()
        }

        $ptForm = $form.PointToClient($curScreen)
        $script:dragGhost.Location = New-Object System.Drawing.Point(($ptForm.X - $script:dragOffset.X), ($ptForm.Y - $script:dragOffset.Y))
    })

    $tile.Add_MouseUp({
        param($s, $e)
        if ($null -eq $script:dragTile -or $script:dragTile -ne $s) { return }
        $me = [System.Windows.Forms.MouseEventArgs]$e
        if ($me.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $s.Capture = $false
        if ($script:dragGhost) {
            $dropPt = $form.PointToClient($s.PointToScreen($me.Location))
            End-TileDrag -dropPoint $dropPt
        } else {
            $script:dragTile        = $null
            $script:dragStartScreen = $null
        }
    })

    $ctxMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $ctxMenu.BackColor = [System.Drawing.Color]::FromArgb(10, 20, 30)
    $ctxMenu.ForeColor = [System.Drawing.Color]::FromArgb(120, 255, 190)
    $ctxMenu.Font      = New-Object System.Drawing.Font('Segoe UI', 9)

    $mRun        = $ctxMenu.Items.Add("  Uruchom")
    $mSep        = $ctxMenu.Items.Add("-")
    $mSep.Name   = "mSep"
    $mOpen       = $ctxMenu.Items.Add("  Otworz lokalizacje")
    $mOpen.Name  = "mOpen"
    $mChangeIcon = $ctxMenu.Items.Add("  Zmień ikonę")
    $mChangeIcon.Name = "mChangeIcon"
    $mFolderMenu = New-Object System.Windows.Forms.ToolStripMenuItem("  Przenieś do folderu")
    $mFolderMenu.Name = "mFolderMenu"
    $ctxMenu.Items.Add($mFolderMenu) | Out-Null
    $mSep2       = $ctxMenu.Items.Add("-")
    $mSep2.Name  = "mSep2"
    $mRemove     = $ctxMenu.Items.Add("  Usun z launcha")
    $mRemove.Name = "mRemove"

    $mRun.Add_Click({ 
        try { 
            Start-Process $tile.Tag 
            Increment-AppLaunchCount -path $tile.Tag
        } catch {} 
    })

    $mChangeIcon.Add_Click({
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Title  = "Wybierz ikonę dla: $($tile.AppName)"
        $ofd.Filter = "Obrazy i ikony|*.png;*.jpg;*.jpeg;*.bmp;*.ico|PNG|*.png|ICO|*.ico|Wszystkie|*.*"
        $ofd.InitialDirectory = [System.Environment]::GetFolderPath('MyPictures')

        if ($ofd.ShowDialog($form) -ne 'OK') { $ofd.Dispose(); return }
        $srcFile = $ofd.FileName; $ofd.Dispose()
        $safeName = ($tile.AppName -replace '[\\/:*?"<>|]', '_').Trim()
        $destPath = Join-Path $script:iconDir "$safeName.png"

        try {
            $bytes  = [System.IO.File]::ReadAllBytes($srcFile)
            $ms     = New-Object System.IO.MemoryStream($bytes, 0, $bytes.Length)
            $srcImg = [System.Drawing.Image]::FromStream($ms)
            $bmp    = New-Object System.Drawing.Bitmap($srcImg.Width, $srcImg.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $gr     = [System.Drawing.Graphics]::FromImage($bmp)
            $gr.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $gr.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $gr.DrawImage($srcImg, 0, 0, $srcImg.Width, $srcImg.Height)
            $gr.Dispose(); $srcImg.Dispose(); $ms.Dispose()
            $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Nie można wczytać wybranego pliku:`n$srcFile", "Błąd ikony", 'OK', 'Warning') | Out-Null
            return
        }

        if ($tile.AppIcon) { try { $tile.AppIcon.Dispose() } catch {} }
        try {
            $rb  = [System.IO.File]::ReadAllBytes($destPath)
            $rms = New-Object System.IO.MemoryStream($rb, 0, $rb.Length)
            $tile.AppIcon = [System.Drawing.Image]::FromStream($rms)
        } catch {}
        $tile.Invalidate()

        $apps = @(Get-AppConfig)
        foreach ($a in $apps) {
            if ((ConvertTo-AbsolutePath $a.Path) -eq (ConvertTo-AbsolutePath $tile.Tag)) {
                $a | Add-Member -NotePropertyName IconFile -NotePropertyValue (ConvertTo-StoredPath $destPath) -Force
            }
        }
        Save-AppConfig -entries $apps
    })

    $mOpen.Add_Click({
        $dir = [System.IO.Path]::GetDirectoryName($tile.Tag)
        if ($dir -and (Test-Path $dir)) { Start-Process 'explorer.exe' $dir }
    })

    $mRemove.Add_Click({ Remove-AppEntry -AppPath $tile.Tag })

    $ctxMenu.Add_Opening({
        $cm          = $this
        $folderItem  = [System.Windows.Forms.ToolStripMenuItem]$cm.Items["mFolderMenu"]
        $changeItem  = $cm.Items["mChangeIcon"]
        $openItem    = $cm.Items["mOpen"]
        $removeItem  = $cm.Items["mRemove"]
        $tilePath = $cm.SourceControl.Tag

        $folderItem.DropDownItems.Clear()
        $miNone = New-Object System.Windows.Forms.ToolStripMenuItem("  (Bez folderu)")
        $miNone.Tag = @{ Path = $tilePath; Folder = "" }
        $miNone.Add_Click({
            param($sender2, $e2)
            $data = $sender2.Tag
            $absP = ConvertTo-AbsolutePath $data.Path
            $script:folderMap[$absP] = ""
            $apps = @(Get-AppConfig)
            foreach ($a in $apps) {
                if ((ConvertTo-AbsolutePath $a.Path) -eq $absP) { $a | Add-Member -NotePropertyName Folder -NotePropertyValue "" -Force }
            }
            Save-AppConfig -entries $apps
            Invoke-TileLayout
        })
        $folderItem.DropDownItems.Add($miNone) | Out-Null

        foreach ($fn in @(Get-FolderList)) {
            $mi = New-Object System.Windows.Forms.ToolStripMenuItem("  $fn")
            $mi.Tag = @{ Path = $tilePath; Folder = $fn }
            $mi.Add_Click({
                param($sender2, $e2)
                $data = $sender2.Tag
                $absP = ConvertTo-AbsolutePath $data.Path
                $script:folderMap[$absP] = $data.Folder
                $apps = @(Get-AppConfig)
                foreach ($a in $apps) {
                    if ((ConvertTo-AbsolutePath $a.Path) -eq $absP) { $a | Add-Member -NotePropertyName Folder -NotePropertyValue $data.Folder -Force }
                }
                Save-AppConfig -entries $apps
                Invoke-TileLayout
            })
            $folderItem.DropDownItems.Add($mi) | Out-Null
        }

        $cm.Items["mSep"].Visible   = $script:isUnlocked
        $folderItem.Enabled = $script:isUnlocked
        $folderItem.Visible = $script:isUnlocked
        $changeItem.Enabled = $script:isUnlocked
        $changeItem.Visible = $script:isUnlocked
        $openItem.Enabled   = $script:isUnlocked
        $openItem.Visible   = $script:isUnlocked
        $cm.Items["mSep2"].Visible  = $script:isUnlocked
        $removeItem.Enabled = $script:isUnlocked
        $removeItem.Visible = $script:isUnlocked
    })

    $tile.ContextMenuStrip = $ctxMenu
    return $tile
}

function Add-AppEntry {
    param([string]$path, [string]$name, [string]$iconFile, [string]$folder = "")
    $absPath = ConvertTo-AbsolutePath $path
    $existing = Get-AppConfig | Where-Object { (ConvertTo-AbsolutePath $_.Path) -eq $absPath }
    if ($existing) {
        [System.Windows.Forms.MessageBox]::Show("Ta aplikacja jest juz na liscie.", "Juz dodane", 'OK', 'Information') | Out-Null
        return
    }
    $storedPath = ConvertTo-StoredPath $absPath
    $storedIcon = ConvertTo-StoredPath (ConvertTo-AbsolutePath $iconFile)
    $newEntry = [PSCustomObject]@{ Name = $name; Path = $storedPath; IconFile = $storedIcon; Folder = $folder; LaunchCount = 0 }
    $all      = @(Get-AppConfig) + @($newEntry)
    Save-AppConfig -entries $all
    $tile = New-TileControl $newEntry
    $form.Controls.Add($tile)
    Invoke-TileLayout
}

function Remove-AppEntry {
    param([string]$AppPath)
    $absAppPath = ConvertTo-AbsolutePath $AppPath
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Usunac '$([System.IO.Path]::GetFileNameWithoutExtension($absAppPath))' z launcha?",
        "Potwierdz usuniecie", 'YesNo', 'Question'
    )
    if ($result -ne 'Yes') { return }

    $toRemove = @($form.Controls | Where-Object { ($_ -is [AppTile]) -and ((ConvertTo-AbsolutePath $_.Tag) -eq $absAppPath) })
    foreach ($t in $toRemove) {
        if ($t.AppIcon) { try { $t.AppIcon.Dispose() } catch {} }
        $form.Controls.Remove($t)
        $t.Dispose()
    }
    $remaining = @(Get-AppConfig | Where-Object { (ConvertTo-AbsolutePath $_.Path) -ne $absAppPath })
    Save-AppConfig -entries $remaining
    Invoke-TileLayout
    Refresh-DashboardTopApps
}

function Invoke-TileLayout {
    if ($script:currentFolder -eq "Dashboard") {
        if ($script:homePanel) { $script:homePanel.Visible = $true }
        foreach ($ctrl in @($form.Controls | Where-Object { $_ -is [AppTile] })) { $ctrl.Visible = $false }
        return
    } else {
        if ($script:homePanel) { $script:homePanel.Visible = $false }
    }

    $gap     = 6
    $size    = $script:tileSize
    $startY  = 62
    $sidebarEdge = if ($script:sidebarPanel) { $script:sidebarPanel.Left + $script:sidebarWidth } else { $script:sidebarWidth }
    $startX  = [Math]::Max(11, $sidebarEdge + 11)
    $formW   = $form.ClientSize.Width
    $availW  = $formW - $startX - 10
    $cols    = [Math]::Max(1, [Math]::Floor($availW / ($size + $gap)))
    $x = $startX; $y = $startY + 10; $col = 0

    $searchTerm = ''
    if ($script:searchBox -and -not $script:searchPlaceholder -and $script:searchBox.Text.Trim() -ne '') {
        $searchTerm = $script:searchBox.Text.Trim().ToLower()
    }

    $lockedFolders = @{}
    foreach ($fo in @(Get-FolderObjects)) {
        if ($fo.PasswordHash -and -not $script:unlockedFolders[$fo.Name]) {
            $lockedFolders[$fo.Name] = $true
        }
    }

    foreach ($ctrl in @($form.Controls | Where-Object { $_ -is [AppTile] })) {
        $tileFolderName = $script:folderMap[$ctrl.Tag]
        if ($script:currentFolder -eq "Wszystkie") { $folderMatch = -not $lockedFolders[$tileFolderName] }
        else { $folderMatch = ($tileFolderName -eq $script:currentFolder) }

        $searchMatch  = ($searchTerm -eq '') -or ($ctrl.AppName.ToLower().Contains($searchTerm))
        if ($folderMatch -and $searchMatch) {
            $ctrl.Visible  = $true
            $ctrl.Location = New-Object System.Drawing.Point($x, $y)
            $ctrl.Size     = New-Object System.Drawing.Size($size, $size)
            $col++
            if ($col -ge $cols) { $col = 0; $x = $startX; $y += $size + $gap } else { $x += $size + $gap }
        } else {
            $ctrl.Visible = $false
        }
    }
}

function Set-TileSize {
    param([int]$size)
    $script:tileSize = $size
    foreach ($ctrl in $form.Controls) { if ($ctrl -is [AppTile]) { $ctrl.Invalidate() } }
    Invoke-TileLayout
}

function Set-EditMode {
    param([bool]$enabled)
    $script:isEditMode = $enabled
    foreach ($ctrl in $form.Controls) {
        if ($ctrl -is [AppTile]) { $ctrl.IsEditMode = $enabled; $ctrl.Invalidate() }
    }
    $sizeSlider.Visible  = $enabled
    $lblSize.Visible     = $enabled
    $lblSizeVal.Visible  = $enabled
    if ($enabled) { $sepLine.BackColor = [System.Drawing.Color]::FromArgb(28, 100, 255, 180) }
    else          { $sepLine.BackColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0) }
    Rebuild-FolderPanel
}

function Handle-DragEnter {
    param($e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        if ($script:isUnlocked) { $e.Effect = 'Copy' } else { $e.Effect = 'None' }
    } else { $e.Effect = 'None' }
}

function Handle-DragDrop {
    param($e)
    if (-not $script:isUnlocked) { return }
    $files = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    if (-not $files) { return }

    foreach ($file in $files) {
        $ext        = [System.IO.Path]::GetExtension($file).ToLower()
        $appName    = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $targetPath = $file
        $iconSource = $file

        if ($ext -eq '.lnk') {
            $resolved = Get-LnkTarget -lnkPath $file
            if ($resolved -and (Test-Path $resolved)) { $targetPath = $resolved } else { $targetPath = $file }
            $iconSource = Get-LnkIcon -lnkPath $file
            if (-not $iconSource) { $iconSource = $targetPath }
        }
        $iconFile = Extract-AppIcon -sourcePath $iconSource -appName $appName
        $folderToAssign = if ($script:currentFolder -eq "Wszystkie" -or $script:currentFolder -eq "Dashboard") { "" } else { $script:currentFolder }
        Add-AppEntry -path $targetPath -name $appName -iconFile $iconFile -folder $folderToAssign
    }
}

function Get-FolderNameInput {
    param([string]$titleText = "Nowy folder", [string]$default = "")

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text            = ""
    $dlg.Size            = New-Object System.Drawing.Size(300, 158)
    $dlg.StartPosition   = 'CenterParent'
    $dlg.FormBorderStyle = 'None'
    $dlg.BackColor       = [System.Drawing.Color]::FromArgb(6, 12, 22)

    $dlg.Add_Paint({
        param($s, $e)
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
        $W = $s.ClientSize.Width; $H = $s.ClientSize.Height
        $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush([System.Drawing.Point]::new(0,0), [System.Drawing.Point]::new(0,$H), [System.Drawing.Color]::FromArgb(10, 18, 34), [System.Drawing.Color]::FromArgb(4, 9, 18))
        $g.FillRectangle($grad, 0, 0, $W, $H); $grad.Dispose()
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 80, 200, 150), 1)
        $g.DrawRectangle($pen, 0, 0, ($W-1), ($H-1)); $pen.Dispose()
        $sepPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(35, 80, 200, 150), 1)
        $g.DrawLine($sepPen, 1, 38, ($W-2), 38); $sepPen.Dispose()
        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, 80, 200, 160))),  10, 10, 18, 18)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 80, 200, 160))), 14, 14, 10, 10)
        $fnt = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $br  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 180, 220, 200))
        $g.DrawString($titleText, $fnt, $br, 36, 11); $fnt.Dispose(); $br.Dispose()
    })

    $dlg.Add_MouseDown({
        param($s, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $e.Y -lt 38) {
            [WinAPI]::ReleaseCapture() | Out-Null
            [WinAPI]::SendMessage($s.Handle, [WinAPI]::WM_NCLBUTTONDOWN, [IntPtr][WinAPI]::HTCAPTION, [IntPtr]::Zero) | Out-Null
        }
    })

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Nazwa folderu:"; $lbl.Location = New-Object System.Drawing.Point(14, 50)
    $lbl.AutoSize = $true; $lbl.BackColor = 'Transparent'
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 200, 170)
    $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $dlg.Controls.Add($lbl)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(14, 70); $txt.Size = New-Object System.Drawing.Size(270, 24)
    $txt.BackColor = [System.Drawing.Color]::FromArgb(10, 22, 38)
    $txt.ForeColor = [System.Drawing.Color]::FromArgb(210, 255, 220)
    $txt.BorderStyle = 'FixedSingle'; $txt.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $txt.Text = $default
    $dlg.Controls.Add($txt)

    function Make-DlgButton($label, $x, $accent) {
        $b = New-Object System.Windows.Forms.Button
        $b.Location = New-Object System.Drawing.Point($x, 108); $b.Size = New-Object System.Drawing.Size(90, 30)
        $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0
        $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::Transparent
        $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::Transparent
        $b.BackColor = 'Transparent'; $b.ForeColor = 'Transparent'
        $b.Tag = @{ hover = $false; label = $label; accent = $accent }

        $b.Add_MouseEnter({ $this.Tag = @{ hover=$true; label=$this.Tag.label; accent=$this.Tag.accent }; $this.Invalidate() })
        $b.Add_MouseLeave({ $this.Tag = @{ hover=$false; label=$this.Tag.label; accent=$this.Tag.accent }; $this.Invalidate() })
        $b.Add_Paint({
            param($s2, $e2)
            $g2 = $e2.Graphics; $g2.SmoothingMode = 'AntiAlias'
            $st = $s2.Tag; $isH = $st.hover; $acc = $st.accent
            $rect2 = New-Object System.Drawing.Rectangle(0, 0, ($s2.Width-1), ($s2.Height-1))
            $path2 = New-Object System.Drawing.Drawing2D.GraphicsPath
            $r2=5; $d2=$r2*2
            $path2.AddArc($rect2.X, $rect2.Y, $d2,$d2, 180, 90)
            $path2.AddArc($rect2.Right-$d2, $rect2.Y, $d2,$d2, 270, 90)
            $path2.AddArc($rect2.Right-$d2, $rect2.Bottom-$d2, $d2,$d2, 0, 90)
            $path2.AddArc($rect2.X, $rect2.Bottom-$d2, $d2,$d2, 90, 90)
            $path2.CloseFigure()
            if ($acc) {
                $bgClr = [System.Drawing.Color]::FromArgb($(if($isH){75}else{40}), 20, 60, 35)
                $boClr = [System.Drawing.Color]::FromArgb($(if($isH){220}else{100}), 80, 210, 140)
                $txClr = [System.Drawing.Color]::FromArgb($(if($isH){255}else{190}), 100, 240, 170)
            } else {
                $bgClr = [System.Drawing.Color]::FromArgb($(if($isH){60}else{30}), 30, 35, 50)
                $boClr = [System.Drawing.Color]::FromArgb($(if($isH){160}else{70}), 100, 120, 160)
                $txClr = [System.Drawing.Color]::FromArgb($(if($isH){210}else{140}), 140, 160, 190)
            }
            $bg2 = New-Object System.Drawing.SolidBrush($bgClr)
            $bo2 = New-Object System.Drawing.Pen($boClr, 1.2)
            $g2.FillPath($bg2, $path2); $g2.DrawPath($bo2, $path2)
            $sf2 = New-Object System.Drawing.StringFormat
            $sf2.Alignment = 'Center'; $sf2.LineAlignment = 'Center'
            $tf2 = New-Object System.Drawing.Font('Segoe UI', 9)
            $tb2 = New-Object System.Drawing.SolidBrush($txClr)
            $g2.DrawString($st.label, $tf2, $tb2, [System.Drawing.RectangleF]::new(0,0,$s2.Width,$s2.Height), $sf2)
            $bg2.Dispose(); $bo2.Dispose(); $sf2.Dispose(); $tf2.Dispose(); $tb2.Dispose(); $path2.Dispose()
        })
        return $b
    }

    $btnOk = Make-DlgButton "OK" 192 $true
    $btnCancel = Make-DlgButton "Anuluj" 98 $false
    $btnOk.DialogResult = 'OK'; $btnCancel.DialogResult = 'Cancel'
    $dlg.Controls.Add($btnOk); $dlg.Controls.Add($btnCancel)
    $dlg.AcceptButton = $btnOk; $dlg.CancelButton = $btnCancel

    $dlg.Add_Shown({ $txt.Focus(); $txt.SelectAll() })

    $result = $dlg.ShowDialog($form)
    $dlg.Dispose()
    if ($result -eq 'OK' -and $txt.Text.Trim() -ne '') { return $txt.Text.Trim() }
    return $null
}

function New-PwdDlgButton {
    param([string]$label, [int]$x, [bool]$accent)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = ""; $b.Location = New-Object System.Drawing.Point($x, 108)
    $b.Size = New-Object System.Drawing.Size(90, 30); $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0; $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::Transparent
    $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::Transparent
    $b.BackColor = 'Transparent'; $b.ForeColor = 'Transparent'
    $lCap = $label; $aCap = $accent
    $b.Tag = @{ hover=$false }
    $b.Add_MouseEnter({ $this.Tag = @{hover=$true};  $this.Invalidate() })
    $b.Add_MouseLeave({ $this.Tag = @{hover=$false}; $this.Invalidate() })
    $b.Add_Paint({
        param($s2,$e2)
        $g2 = $e2.Graphics; $g2.SmoothingMode = 'AntiAlias'
        $isH = $s2.Tag.hover
        $r2 = New-Object System.Drawing.Rectangle(0,0,($s2.Width-1),($s2.Height-1))
        $p2 = New-Object System.Drawing.Drawing2D.GraphicsPath
        $p2.AddArc($r2.X,$r2.Y,10,10,180,90); $p2.AddArc($r2.Right-10,$r2.Y,10,10,270,90)
        $p2.AddArc($r2.Right-10,$r2.Bottom-10,10,10,0,90); $p2.AddArc($r2.X,$r2.Bottom-10,10,10,90,90)
        $p2.CloseFigure()
        if ($aCap) {
            $bg2 = [System.Drawing.Color]::FromArgb($(if($isH){75}else{35}),20,40,60)
            $bo2 = [System.Drawing.Color]::FromArgb($(if($isH){220}else{90}),100,150,220)
            $tx2 = [System.Drawing.Color]::FromArgb($(if($isH){255}else{180}),140,190,255)
        } else {
            $bg2 = [System.Drawing.Color]::FromArgb($(if($isH){60}else{28}),28,30,45)
            $bo2 = [System.Drawing.Color]::FromArgb($(if($isH){150}else{60}),100,110,150)
            $tx2 = [System.Drawing.Color]::FromArgb($(if($isH){200}else{130}),140,150,180)
        }
        $bb2 = New-Object System.Drawing.SolidBrush($bg2); $bp2 = New-Object System.Drawing.Pen($bo2, 1.2)
        $g2.FillPath($bb2,$p2); $g2.DrawPath($bp2,$p2)
        $sf2 = New-Object System.Drawing.StringFormat
        $sf2.Alignment = 'Center'; $sf2.LineAlignment = 'Center'
        $tf2 = New-Object System.Drawing.Font('Segoe UI',9); $tb2 = New-Object System.Drawing.SolidBrush($tx2)
        $g2.DrawString($lCap,$tf2,$tb2,[System.Drawing.RectangleF]::new(0,0,$s2.Width,$s2.Height),$sf2)
        $bb2.Dispose();$bp2.Dispose();$sf2.Dispose();$tf2.Dispose();$tb2.Dispose();$p2.Dispose()
    }.GetNewClosure())
    return $b
}

function Show-PasswordDialog {
    param([string]$titleText = "Hasło folderu", [string]$promptText = "Wprowadź hasło:")
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text            = ""
    $dlg.Size            = New-Object System.Drawing.Size(300, 158)
    $dlg.StartPosition   = 'CenterParent'
    $dlg.FormBorderStyle = 'None'
    $dlg.BackColor       = [System.Drawing.Color]::FromArgb(6, 12, 22)

    $dlg.Add_Paint({
        param($s, $e)
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
        $W = $s.ClientSize.Width; $H = $s.ClientSize.Height
        $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush([System.Drawing.Point]::new(0,0), [System.Drawing.Point]::new(0,$H), [System.Drawing.Color]::FromArgb(10,18,34), [System.Drawing.Color]::FromArgb(4,9,18))
        $g.FillRectangle($grad, 0, 0, $W, $H); $grad.Dispose()
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70,100,140,200), 1)
        $g.DrawRectangle($pen, 0, 0, ($W-1), ($H-1)); $pen.Dispose()
        $sp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(35,100,140,200), 1)
        $g.DrawLine($sp, 1, 38, ($W-2), 38); $sp.Dispose()
        $icC = [System.Drawing.Color]::FromArgb(200, 120, 160, 220); $icP = New-Object System.Drawing.Pen($icC, 1.5)
        $g.DrawRectangle($icP, 10, 18, 14, 10); $g.DrawArc($icP, 12, 10, 10, 12, 180, 180); $icP.Dispose()
        $fnt = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $br  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,180,200,230))
        $g.DrawString($titleText, $fnt, $br, 36, 11); $fnt.Dispose(); $br.Dispose()
    })

    $dlg.Add_MouseDown({
        param($s, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $e.Y -lt 38) {
            [WinAPI]::ReleaseCapture() | Out-Null
            [WinAPI]::SendMessage($s.Handle, [WinAPI]::WM_NCLBUTTONDOWN, [IntPtr][WinAPI]::HTCAPTION, [IntPtr]::Zero) | Out-Null
        }
    })

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $promptText; $lbl.Location = New-Object System.Drawing.Point(14, 50)
    $lbl.AutoSize = $true; $lbl.BackColor = 'Transparent'
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(140,140,180,210)
    $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $dlg.Controls.Add($lbl)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(14, 70); $txt.Size = New-Object System.Drawing.Size(270, 24)
    $txt.BackColor = [System.Drawing.Color]::FromArgb(10,22,38)
    $txt.ForeColor = [System.Drawing.Color]::FromArgb(210,200,220,255)
    $txt.BorderStyle = 'FixedSingle'; $txt.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $txt.PasswordChar = [char]0x25CF
    $dlg.Controls.Add($txt)

    $btnOk = New-PwdDlgButton -label "OK" -x 192 -accent $true
    $btnCancel = New-PwdDlgButton -label "Anuluj" -x 98 -accent $false
    $btnOk.DialogResult = 'OK'; $btnCancel.DialogResult = 'Cancel'
    $dlg.Controls.Add($btnOk); $dlg.Controls.Add($btnCancel)
    $dlg.AcceptButton = $btnOk; $dlg.CancelButton = $btnCancel
    $dlg.Add_Shown({ $txt.Focus() })

    $result = $dlg.ShowDialog($form)
    $pwd = $txt.Text; $dlg.Dispose()
    if ($result -eq 'OK') { return $pwd } else { return $null }
}

function Set-FolderPassword {
    param([string]$folderName)
    $p1 = Show-PasswordDialog -titleText "Ustaw hasło — $folderName" -promptText "Nowe hasło:"
    if ($null -eq $p1) { return }
    if ($p1 -eq "") { [System.Windows.Forms.MessageBox]::Show("Hasło nie może być puste.", "Błąd", 'OK', 'Warning') | Out-Null; return }
    $p2 = Show-PasswordDialog -titleText "Potwierdź hasło — $folderName" -promptText "Powtórz hasło:"
    if ($null -eq $p2) { return }
    if ($p1 -ne $p2) { [System.Windows.Forms.MessageBox]::Show("Hasła nie są identyczne.", "Błąd", 'OK', 'Warning') | Out-Null; return }
    Set-FolderPasswordHash -folderName $folderName -hash (Get-SHA256Hash $p1)
    $script:unlockedFolders[$folderName] = $true
    Rebuild-FolderPanel
}

function Remove-FolderPassword {
    param([string]$folderName)
    $hash = Get-FolderPasswordHash -folderName $folderName
    if (-not $hash) { return }
    $p = Show-PasswordDialog -titleText "Usuń hasło — $folderName" -promptText "Aktualne hasło:"
    if ($null -eq $p) { return }
    if ((Get-SHA256Hash $p) -ne $hash) { [System.Windows.Forms.MessageBox]::Show("Nieprawidłowe hasło.", "Błąd", 'OK', 'Warning') | Out-Null; return }
    Set-FolderPasswordHash -folderName $folderName -hash ""
    $script:unlockedFolders.Remove($folderName)
    Rebuild-FolderPanel
}

function Test-FolderAccess {
    param([string]$folderName)
    if ($folderName -eq "Wszystkie" -or $folderName -eq "Dashboard") { return $true }
    $hash = Get-FolderPasswordHash -folderName $folderName
    if (-not $hash) { return $true }
    if ($script:unlockedFolders[$folderName]) { return $true }
    $p = Show-PasswordDialog -titleText "🔒 $folderName" -promptText "Wprowadź hasło:"
    if ($null -eq $p) { return $false }
    if ((Get-SHA256Hash $p) -eq $hash) { $script:unlockedFolders[$folderName] = $true; return $true }
    [System.Windows.Forms.MessageBox]::Show("Nieprawidłowe hasło.", "Błąd", 'OK', 'Warning') | Out-Null
    return $false
}

function Remove-Folder {
    param([string]$folderName)
    if ($folderName -eq "Wszystkie" -or $folderName -eq "Dashboard") { return }
    $result = [System.Windows.Forms.MessageBox]::Show("Usunac folder '$folderName'?`nAplikacje zostana przeniesione do 'Wszystkie'.", "Potwierdz usuniecie folderu", 'YesNo', 'Question')
    if ($result -ne 'Yes') { return }

    $apps = @(Get-AppConfig)
    foreach ($a in $apps) { if ($a.Folder -eq $folderName) { $a | Add-Member -NotePropertyName Folder -NotePropertyValue "" -Force } }
    Save-AppConfig -entries $apps

    foreach ($ctrl in @($form.Controls | Where-Object { $_ -is [AppTile] })) {
        if ($script:folderMap[$ctrl.Tag] -eq $folderName) { $script:folderMap[$ctrl.Tag] = "" }
    }

    $folders = @(Get-FolderList | Where-Object { $_ -ne $folderName })
    Save-FolderList -folders $folders
    $script:unlockedFolders.Remove($folderName)

    if ($script:currentFolder -eq $folderName) { $script:currentFolder = "Wszystkie" }
    Rebuild-FolderPanel; Invoke-TileLayout
}

function Rename-Folder {
    param([string]$folderName)
    if ($folderName -eq "Wszystkie" -or $folderName -eq "Dashboard") { return }
    $newName = Get-FolderNameInput -titleText "Zmień nazwę folderu" -default $folderName
    if (-not $newName -or $newName -eq $folderName) { return }

    $existing = Get-FolderList
    if ($existing -contains $newName) { [System.Windows.Forms.MessageBox]::Show("Folder '$newName' już istnieje.", "Duplikat", 'OK', 'Information') | Out-Null; return }

    $folders = @($existing | ForEach-Object { if ($_ -eq $folderName) { $newName } else { $_ } })
    Save-FolderList -folders $folders

    $apps = @(Get-AppConfig)
    foreach ($a in $apps) { if ($a.Folder -eq $folderName) { $a | Add-Member -NotePropertyName Folder -NotePropertyValue $newName -Force } }
    Save-AppConfig -entries $apps

    foreach ($key in @($script:folderMap.Keys)) { if ($script:folderMap[$key] -eq $folderName) { $script:folderMap[$key] = $newName } }
    if ($script:currentFolder -eq $folderName) { $script:currentFolder = $newName }
    Rebuild-FolderPanel; Invoke-TileLayout
}

function New-FolderButton {
    param([string]$text, [int]$y, [bool]$selected = $false, [bool]$editMode = $false, [string]$folderName = "", [bool]$isLocked = $false)

    $btnW = $script:sidebarWidth - 16; $btnText = $text; $btnLock = $isLocked; $btnThemeNow = $script:currentTheme
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = ""; $btn.Location = New-Object System.Drawing.Point(8, $y); $btn.Size = New-Object System.Drawing.Size($btnW, 30)
    $btn.FlatStyle = 'Flat'; $btn.FlatAppearance.BorderSize = 0; $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::Transparent
    $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::Transparent; $btn.BackColor = [System.Drawing.Color]::Transparent
    $btn.ForeColor = [System.Drawing.Color]::Transparent; $btn.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $btn.Tag = @{ hover = $false; selected = $selected }

    $btn.Add_MouseEnter({ $this.Tag = @{ hover = $true;  selected = $this.Tag.selected }; $this.Invalidate() })
    $btn.Add_MouseLeave({ $this.Tag = @{ hover = $false; selected = $this.Tag.selected }; $this.Invalidate() })

    $btn.Add_Paint({
        param($s, $e)
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
        $state = $s.Tag; $isHov = $state.hover; $isSel = $state.selected
        $rect = New-Object System.Drawing.Rectangle(0, 0, ($s.Width - 1), ($s.Height - 1))
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $r = 5; $d = $r * 2
        $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
        $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
        $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
        $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
        $path.CloseFigure()

        $bgA  = if ($isSel) { 85 } elseif ($isHov) { 55 } else { 18 }
        $pA   = if ($isSel) { 210 } elseif ($isHov) { 120 } else { 38 }
        $pw   = if ($isSel) { 1.5 } else { 1.0 }

        switch ($btnThemeNow) {
            1 { $bgAD = if ($isSel) { 220 } elseif ($isHov) { 160 } else { 90 }
                $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($bgAD, 55, 55, 55))
                $pen   = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($pA, 110, 110, 110), $pw) }
            2 { $bgAL = if ($isSel) { 255 } elseif ($isHov) { 200 } else { 120 }
                $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($bgAL, 200, 200, 200))
                $pen   = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(($pA + 40), 80, 80, 80), $pw) }
            3 { $bgAM = if ($isSel) { 150 } elseif ($isHov) { 90 } else { 40 }
                $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($bgAM, 100, 150, 200))
                $pen   = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($pA, 130, 180, 230), $pw) }
            default { $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($bgA, 10, 38, 22))
                      $pen   = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($pA, 80, 210, 150), $pw) }
        }
        $g.FillPath($brush, $path); $g.DrawPath($pen, $path)

        $textW = if ($btnLock) { $s.Width - 24 } else { $s.Width - 12 }
        $sf  = New-Object System.Drawing.StringFormat
        $sf.Alignment = 'Near'; $sf.LineAlignment = 'Center'; $sf.Trimming = 'EllipsisCharacter'
        $tA  = if ($isSel) { 255 } elseif ($isHov) { 215 } else { 155 }

        switch ($btnThemeNow) {
            1 { $tBr = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($tA, 195, 195, 195)) }
            2 { $tBr = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($tA, 40,  40,  40))  }
            3 { $tBr = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($tA, 220, 240, 255)) }
            default { $tBr = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($tA, 115, 245, 175)) }
        }
        $tF = New-Object System.Drawing.Font('Segoe UI', 8.5, $(if ($isSel) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }))
        $g.DrawString($btnText, $tF, $tBr, ([System.Drawing.RectangleF]::new(8, 0, $textW, $s.Height)), $sf)

        if ($btnLock) {
            $lkA = if ($isHov) { 210 } else { 140 }
            switch ($btnThemeNow) {
                1 { $lkC = [System.Drawing.Color]::FromArgb($lkA, 170, 155, 100) }
                2 { $lkC = [System.Drawing.Color]::FromArgb($lkA, 140, 110, 40)  }
                3 { $lkC = [System.Drawing.Color]::FromArgb($lkA, 160, 200, 240) }
                default { $lkC = [System.Drawing.Color]::FromArgb($lkA, 200, 160, 100) }
            }
            $lkP = New-Object System.Drawing.Pen($lkC, 1.2); $lkX = $s.Width - 16; $lkY = ($s.Height - 10) / 2
            $g.DrawRectangle($lkP, $lkX, ($lkY + 4), 8, 6); $g.DrawArc($lkP, ($lkX + 1), $lkY, 6, 6, 180, 180); $lkP.Dispose()
        }
        $brush.Dispose(); $pen.Dispose(); $tBr.Dispose(); $tF.Dispose(); $path.Dispose(); $sf.Dispose()
    }.GetNewClosure())

    if ($editMode -and $folderName -ne "Wszystkie" -and $folderName -ne "Dashboard" -and $folderName -ne "") {
        $ctx = New-Object System.Windows.Forms.ContextMenuStrip
        switch ($btnThemeNow) {
            1 { $ctx.BackColor = [System.Drawing.Color]::FromArgb(42, 42, 42); $ctx.ForeColor = [System.Drawing.Color]::FromArgb(190, 190, 190) }
            2 { $ctx.BackColor = [System.Drawing.Color]::FromArgb(220, 220, 220); $ctx.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40) }
            3 { $ctx.BackColor = [System.Drawing.Color]::FromArgb(25, 40, 55); $ctx.ForeColor = [System.Drawing.Color]::FromArgb(200, 230, 255) }
            default { $ctx.BackColor = [System.Drawing.Color]::FromArgb(10, 20, 30); $ctx.ForeColor = [System.Drawing.Color]::FromArgb(120, 255, 190) }
        }

        $allFN = @(Get-FolderList); $fnIdx = [array]::IndexOf($allFN, $folderName); $fnCap = $folderName
        if ($fnIdx -gt 0) {
            $mUp = $ctx.Items.Add("  ↑  Przenieś wyżej"); $mUp.Add_Click({ Move-FolderUp -folderName $fnCap }.GetNewClosure())
        }
        if ($fnIdx -lt ($allFN.Count - 1)) {
            $mDn = $ctx.Items.Add("  ↓  Przenieś niżej"); $mDn.Add_Click({ Move-FolderDown -folderName $fnCap }.GetNewClosure())
        }
        $ctx.Items.Add("-") | Out-Null
        $mRen = $ctx.Items.Add("  Zmień nazwę")
        $hasPassword = ((Get-FolderPasswordHash -folderName $folderName) -ne "")
        if ($hasPassword) {
            $mPwd = $ctx.Items.Add("  Zmień hasło"); $mPwd.Add_Click({ Set-FolderPassword -folderName $fnCap }.GetNewClosure())
            $mUnpwd = $ctx.Items.Add("  Usuń hasło"); $mUnpwd.Add_Click({ Remove-FolderPassword -folderName $fnCap }.GetNewClosure())
        } else {
            $mPwd = $ctx.Items.Add("  Ustaw hasło"); $mPwd.Add_Click({ Set-FolderPassword -folderName $fnCap }.GetNewClosure())
        }
        $ctx.Items.Add("-") | Out-Null
        $mDel = $ctx.Items.Add("  Usuń folder"); $mRen.Add_Click({ Rename-Folder -folderName $fnCap }.GetNewClosure())
        $mDel.Add_Click({ Remove-Folder -folderName $fnCap }.GetNewClosure())
        $btn.ContextMenuStrip = $ctx
    }
    return $btn
}

function Rebuild-FolderPanel {
    if (-not $script:sidebarPanel) { return }
    $old = @($script:sidebarPanel.Controls)
    foreach ($c in $old) { $script:sidebarPanel.Controls.Remove($c); $c.Dispose() }

    $yOff = 8; $btnH = 30; $gap = 4
    
    # Przycisk DASHBOARD na samej górze
    $isHomeSel = ($script:currentFolder -eq "Dashboard")
    $fBtnHome = New-FolderButton -text "🏠 Strona Główna" -y $yOff -selected $isHomeSel -editMode $false -folderName "Dashboard" -isLocked $false
    $fBtnHome.Name = "Dashboard"
    $fBtnHome.Add_Click({
        $script:currentFolder = "Dashboard"
        Rebuild-FolderPanel; Invoke-TileLayout
    })
    $script:sidebarPanel.Controls.Add($fBtnHome); $yOff += $btnH + $gap
    
    $sepP = New-Object DBPanel
    $sepP.Location = New-Object System.Drawing.Point(8, $yOff); $sepP.Size = New-Object System.Drawing.Size(($script:sidebarWidth - 16), 1)
    $sepP.BackColor = [System.Drawing.Color]::FromArgb(40, 255, 255, 255); $script:sidebarPanel.Controls.Add($sepP); $yOff += 6

    $allFolders = @("Wszystkie") + @(Get-FolderList)

    foreach ($fn in $allFolders) {
        $isSel = ($fn -eq $script:currentFolder)
        $hasPass = ($fn -ne "Wszystkie") -and ((Get-FolderPasswordHash -folderName $fn) -ne "")
        $isLocked = $hasPass -and (-not $script:unlockedFolders[$fn])
        $fBtn = New-FolderButton -text $fn -y $yOff -selected $isSel -editMode $script:isEditMode -folderName $fn -isLocked $isLocked
        $fBtn.Name = $fn
        $fBtn.Add_Click({
            $fn2 = $this.Name
            if (Test-FolderAccess -folderName $fn2) { $script:currentFolder = $fn2; Rebuild-FolderPanel; Invoke-TileLayout }
        })
        $script:sidebarPanel.Controls.Add($fBtn); $yOff += $btnH + $gap
    }

    if ($script:isEditMode) {
        $yOff += 4
        $addBtn = New-Object System.Windows.Forms.Button
        $addBtn.Text = "+ Nowy folder"; $addBtn.Location = New-Object System.Drawing.Point(8, $yOff)
        $addBtn.Size = New-Object System.Drawing.Size(($script:sidebarWidth - 16), 28)
        $addBtn.FlatStyle = 'Flat'; $addBtn.FlatAppearance.BorderSize = 1; $addBtn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::Transparent
        switch ($script:currentTheme) {
            1 { $addBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
                $addBtn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(64, 64, 64)
                $addBtn.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50); $addBtn.ForeColor = [System.Drawing.Color]::FromArgb(190, 190, 190) }
            2 { $addBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(130, 130, 130)
                $addBtn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(192, 192, 192)
                $addBtn.BackColor = [System.Drawing.Color]::FromArgb(210, 210, 210); $addBtn.ForeColor = [System.Drawing.Color]::FromArgb(40,  40,  40) }
            3 { $addBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(80, 130, 180)
                $addBtn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(50, 75, 105)
                $addBtn.BackColor = [System.Drawing.Color]::FromArgb(35, 50, 70); $addBtn.ForeColor = [System.Drawing.Color]::FromArgb(180, 220, 255) }
            default { $addBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60, 80, 200, 140)
                $addBtn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(30, 60, 180, 120)
                $addBtn.BackColor = [System.Drawing.Color]::FromArgb(12, 28, 20); $addBtn.ForeColor = [System.Drawing.Color]::FromArgb(160, 100, 220, 160) }
        }
        $addBtn.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Regular)
        $addBtn.Add_Click({
            $newName = Get-FolderNameInput -titleText "Nowy folder"
            if ($newName) {
                $existing = Get-FolderList
                if ($existing -contains $newName) { [System.Windows.Forms.MessageBox]::Show("Folder '$newName' juz istnieje.", "Duplikat", 'OK', 'Information') | Out-Null; return }
                $updated = @($existing) + @($newName); Save-FolderList -folders $updated
                $script:currentFolder = $newName; Rebuild-FolderPanel; Invoke-TileLayout
            }
        })
        $script:sidebarPanel.Controls.Add($addBtn)
    }

    # ─── Klódka przypinająca panel ────────────────────────────────────────────
    $pinSize = 28
    $pinX    = ($script:sidebarWidth - $pinSize) / 2
    $script:sidebarPinBtn = New-Object System.Windows.Forms.Button
    $script:sidebarPinBtn.Location = New-Object System.Drawing.Point($pinX, ($script:sidebarPanel.Height - $pinSize - 6))
    $script:sidebarPinBtn.Size     = New-Object System.Drawing.Size($pinSize, $pinSize)
    $script:sidebarPinBtn.Anchor   = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
    $script:sidebarPinBtn.FlatStyle = 'Flat'
    $script:sidebarPinBtn.FlatAppearance.BorderSize = 0
    $script:sidebarPinBtn.FlatAppearance.MouseOverBackColor  = [System.Drawing.Color]::Transparent
    $script:sidebarPinBtn.FlatAppearance.MouseDownBackColor  = [System.Drawing.Color]::Transparent
    $script:sidebarPinBtn.BackColor = [System.Drawing.Color]::Transparent
    $script:sidebarPinBtn.ForeColor = [System.Drawing.Color]::Transparent
    $script:sidebarPinBtn.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $script:sidebarPinBtn.Text      = ""

    $pinIsLocked = $script:sidebarPinned
    $pinTheme    = $script:currentTheme
    $script:sidebarPinBtn.Tag = @{ hover = $false }

    $script:sidebarPinBtn.Add_MouseEnter({ $this.Tag = @{ hover = $true  }; $this.Invalidate() })
    $script:sidebarPinBtn.Add_MouseLeave({ $this.Tag = @{ hover = $false }; $this.Invalidate() })

    $script:sidebarPinBtn.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $W = $s.Width; $H = $s.Height
        $cx = $W / 2.0; $cy = $H / 2.0
        $isH = $s.Tag.hover

        $hA = if ($isH) { 220 } else { 150 }
        $lA = if ($isH) { 120 } else { 65 }
        if ($pinTheme -eq 1) {
            $baseClr = if ($pinIsLocked) { [System.Drawing.Color]::FromArgb($hA, 190, 190, 190) } else { [System.Drawing.Color]::FromArgb($lA, 160, 160, 160) }
        } elseif ($pinTheme -eq 2) {
            $baseClr = if ($pinIsLocked) { [System.Drawing.Color]::FromArgb($hA, 40, 40, 40) }   else { [System.Drawing.Color]::FromArgb($lA, 80, 80, 80) }
        } elseif ($pinTheme -eq 3) {
            $baseClr = if ($pinIsLocked) { [System.Drawing.Color]::FromArgb($hA, 140, 200, 255) } else { [System.Drawing.Color]::FromArgb($lA, 80, 140, 200) }
        } else {
            $baseClr = if ($pinIsLocked) { [System.Drawing.Color]::FromArgb($hA, 80, 220, 155) } else { [System.Drawing.Color]::FromArgb($lA, 40, 130, 90) }
        }

        # Korpus kłódki
        $bx = [float]($cx - 5.5); $by = [float]($cy + 0.5); $bw = 11.0; $bh = 9.0
        $bp = New-Object System.Drawing.Drawing2D.GraphicsPath
        $br2 = 2.0; $bd2 = $br2 * 2
        $bp.AddArc($bx,              $by,              $bd2, $bd2, 180, 90)
        $bp.AddArc($bx + $bw - $bd2, $by,              $bd2, $bd2, 270, 90)
        $bp.AddArc($bx + $bw - $bd2, $by + $bh - $bd2, $bd2, $bd2,   0, 90)
        $bp.AddArc($bx,              $by + $bh - $bd2, $bd2, $bd2,  90, 90)
        $bp.CloseFigure()
        $fillA   = [int]($baseClr.A * 0.18)
        $fillClr = [System.Drawing.Color]::FromArgb($fillA, $baseClr.R, $baseClr.G, $baseClr.B)
        $fillBr  = New-Object System.Drawing.SolidBrush($fillClr)
        $g.FillPath($fillBr, $bp)
        $bodyPen = New-Object System.Drawing.Pen($baseClr, 1.5)
        $g.DrawPath($bodyPen, $bp)
        $fillBr.Dispose(); $bodyPen.Dispose(); $bp.Dispose()

        # Dziurka
        $holeBr = New-Object System.Drawing.SolidBrush($baseClr)
        $g.FillEllipse($holeBr, [float]($cx - 1.6), [float]($by + $bh * 0.28), 3.2, 3.2)
        $holeBr.Dispose()

        # Pałąk
        $shackPen = New-Object System.Drawing.Pen($baseClr, 1.8)
        $shackPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $shackPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
        $arcX = [float]($cx - 4.0); $arcW = 8.0; $arcH = 8.0
        if ($pinIsLocked) {
            $g.DrawArc($shackPen, $arcX, [float]($cy - $arcH + 0.5), $arcW, $arcH, 180, 180)
        } else {
            $g.DrawArc($shackPen, [float]($arcX + 2.5), [float]($cy - $arcH), $arcW, $arcH, 200, 160)
        }
        $shackPen.Dispose()
    }.GetNewClosure())

    $script:sidebarPanel.Controls.Add($script:sidebarPinBtn)

    $script:sidebarPinBtn.Add_Click({
        $script:sidebarPinned = -not $script:sidebarPinned
        if ($script:sidebarPinned) {
            $script:sidebarCurrentX = [double]$script:sidebarPanel.Left
            $script:sidebarTargetX  = 0
            $script:sidebarReachedTarget = $false
            $script:sidebarPanel.BringToFront()
            $form.SuspendLayout()
            $script:sidebarAnimTimer.Start()
        }
        Rebuild-FolderPanel
    })
}

# ===========================================================
#   BUDOWA FORMULARZA
# ===========================================================

$form = New-Object AuroraDeck
$form.FormTitle   = "Aurora Deck"
$form.Size        = New-Object System.Drawing.Size(920, 680)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize   = New-Object System.Drawing.Size(650, 500)
$form.AllowDrop     = $true

# ─── DODANA IKONA Z PLIKU PNG ────────────────────────────
$iconPath = Join-Path $script:scriptDir "iconb.png"
if (Test-Path $iconPath) {
    try {
        $bmp = [System.Drawing.Bitmap]::FromFile($iconPath)
        $hIcon = $bmp.GetHicon()
        $form.Icon = [System.Drawing.Icon]::FromHandle($hIcon)
    } catch {}
}

# ===========================================================
#   STRONA GŁÓWNA (DASHBOARD)
# ===========================================================

$script:homePanel = New-Object DBPanel
$script:homePanel.Location = New-Object System.Drawing.Point($script:sidebarWidth, 57)
$script:homePanel.Size     = New-Object System.Drawing.Size(($form.Width - $script:sidebarWidth), ($form.Height - 57 - 55))
$script:homePanel.Anchor   = 'Top, Bottom, Left, Right'
$script:homePanel.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($script:homePanel)

$script:lblClock = New-Object System.Windows.Forms.Label
$script:lblClock.Font = New-Object System.Drawing.Font('Segoe UI', 48, [System.Drawing.FontStyle]::Bold)
$script:lblClock.AutoSize = $true
$script:lblClock.Location = New-Object System.Drawing.Point(40, 30)
Enable-DoubleBuffer $script:lblClock
$script:homePanel.Controls.Add($script:lblClock)

$script:lblDate = New-Object System.Windows.Forms.Label
$script:lblDate.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Regular)
$script:lblDate.AutoSize = $true
$script:lblDate.Location = New-Object System.Drawing.Point(48, 140)
Enable-DoubleBuffer $script:lblDate
$script:homePanel.Controls.Add($script:lblDate)

$script:lblWeather = New-Object System.Windows.Forms.Label
$script:lblWeather.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Regular)
$script:lblWeather.AutoSize = $true
$script:lblWeather.Location = New-Object System.Drawing.Point(380, 55)
$script:lblWeather.Text = "Pobieranie pogody..."
Enable-DoubleBuffer $script:lblWeather
$script:homePanel.Controls.Add($script:lblWeather)

# --- To-Do List ---
$script:todoFile    = Join-Path $script:scriptDir "todo.json"
$script:historyFile = Join-Path $script:scriptDir "todo_history.json"
$script:todoForeColor = [System.Drawing.Color]::FromArgb(180, 255, 200)

function Get-TodoHistory {
    if (Test-Path $script:historyFile) {
        try { return @(Get-Content $script:historyFile -Raw | ConvertFrom-Json) } catch {}
    }
    return @()
}

function Add-ToHistory {
    param([string]$text, [bool]$done, [string]$createdAt, [string]$notes, [string]$reason)
    $history = Get-TodoHistory
    $entry = [PSCustomObject]@{
        Text       = $text
        Done       = $done
        CreatedAt  = $createdAt
        Notes      = $notes
        ArchivedAt = (Get-Date -Format 'dd.MM.yy HH:mm')
        Reason     = $reason
    }
    $history = @($entry) + $history
    $history | ConvertTo-Json | Set-Content $script:historyFile -Encoding UTF8
}

function Get-TodoItems {
    if (Test-Path $script:todoFile) {
        try { return @(Get-Content $script:todoFile -Raw | ConvertFrom-Json) } catch {}
    }
    return @()
}

function Save-TodoItems {
    $items = @()
    foreach ($row in $script:todoFlow.Controls) {
        if ($row -is [DBPanel]) {
            $cb = $row.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | Select-Object -First 1
            if ($cb) {
                $tagObj = $row.Tag
                $createdAt = if ($tagObj -is [PSCustomObject] -and $tagObj.CreatedAt) { $tagObj.CreatedAt } else { "$tagObj" }
                $notes = if ($tagObj -is [PSCustomObject] -and $tagObj.Notes) { $tagObj.Notes } else { "" }
                $items += [PSCustomObject]@{ Text = $cb.Text; Done = $cb.Checked; CreatedAt = $createdAt; Notes = $notes }
            }
        }
    }
    $items | ConvertTo-Json | Set-Content $script:todoFile -Encoding UTF8
}

function Show-TodoHistoryWindow {
    $thm = if ($form.Tag -is [int]) { $form.Tag } else { 0 }
    switch ($thm) {
        1 { $bgTop=[System.Drawing.Color]::FromArgb(36,36,36); $bgBot=[System.Drawing.Color]::FromArgb(18,18,18)
            $borderC=[System.Drawing.Color]::FromArgb(80,120,120,120); $titleC=[System.Drawing.Color]::FromArgb(200,200,200)
            $inputBg=[System.Drawing.Color]::FromArgb(46,46,46); $inputFg=[System.Drawing.Color]::FromArgb(200,200,200)
            $doneC=[System.Drawing.Color]::FromArgb(100,200,100); $delC=[System.Drawing.Color]::FromArgb(200,100,100) }
        2 { $bgTop=[System.Drawing.Color]::FromArgb(240,240,240); $bgBot=[System.Drawing.Color]::FromArgb(220,220,220)
            $borderC=[System.Drawing.Color]::FromArgb(150,130,130,130); $titleC=[System.Drawing.Color]::FromArgb(50,50,50)
            $inputBg=[System.Drawing.Color]::FromArgb(250,250,250); $inputFg=[System.Drawing.Color]::FromArgb(50,50,50)
            $doneC=[System.Drawing.Color]::FromArgb(50,160,50); $delC=[System.Drawing.Color]::FromArgb(180,60,60) }
        3 { $bgTop=[System.Drawing.Color]::FromArgb(22,35,50); $bgBot=[System.Drawing.Color]::FromArgb(14,24,38)
            $borderC=[System.Drawing.Color]::FromArgb(80,80,130,180); $titleC=[System.Drawing.Color]::FromArgb(190,220,245)
            $inputBg=[System.Drawing.Color]::FromArgb(25,40,55); $inputFg=[System.Drawing.Color]::FromArgb(190,220,245)
            $doneC=[System.Drawing.Color]::FromArgb(100,200,255); $delC=[System.Drawing.Color]::FromArgb(200,120,120) }
        default { $bgTop=[System.Drawing.Color]::FromArgb(10,18,34); $bgBot=[System.Drawing.Color]::FromArgb(4,9,18)
            $borderC=[System.Drawing.Color]::FromArgb(70,80,200,150); $titleC=[System.Drawing.Color]::FromArgb(180,220,200)
            $inputBg=[System.Drawing.Color]::FromArgb(10,22,38); $inputFg=[System.Drawing.Color]::FromArgb(180,255,200)
            $doneC=[System.Drawing.Color]::FromArgb(100,220,160); $delC=[System.Drawing.Color]::FromArgb(200,100,100) }
    }

    $bgTopARGB = $bgTop.ToArgb(); $bgBotARGB = $bgBot.ToArgb()
    $borderARGB = $borderC.ToArgb(); $titleARGB = $titleC.ToArgb()

    $wh = New-Object System.Windows.Forms.Form
    $wh.Text = ""; $wh.Size = New-Object System.Drawing.Size(360, 420)
    $wh.StartPosition = 'CenterParent'; $wh.FormBorderStyle = 'None'
    $wh.MaximizeBox = $false; $wh.MinimizeBox = $false
    $wh.ShowInTaskbar = $false; $wh.BackColor = $bgBot; $wh.Tag = $thm

    $wh.Add_Paint({
        param($s, $e)
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
        $W = $s.ClientSize.Width; $H = $s.ClientSize.Height
        $cTop = [System.Drawing.Color]::FromArgb($bgTopARGB); $cBot2 = [System.Drawing.Color]::FromArgb($bgBotARGB)
        $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush([System.Drawing.Point]::new(0,0),[System.Drawing.Point]::new(0,$H),$cTop,$cBot2)
        $g.FillRectangle($grad,0,0,$W,$H); $grad.Dispose()
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($borderARGB),1)
        $g.DrawRectangle($pen,0,0,($W-1),($H-1)); $pen.Dispose()
        $sep = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($borderARGB),1)
        $g.DrawLine($sep,1,40,($W-2),40); $sep.Dispose()
        $fnt = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
        $br  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($titleARGB))
        $g.DrawString("Historia zadań",$fnt,$br,12,12); $fnt.Dispose(); $br.Dispose()
    }.GetNewClosure())

    $wh.Add_MouseDown({
        param($s,$e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $e.Y -lt 40) {
            [WinAPI]::ReleaseCapture() | Out-Null
            [WinAPI]::SendMessage($s.Handle,[WinAPI]::WM_NCLBUTTONDOWN,[IntPtr][WinAPI]::HTCAPTION,[IntPtr]::Zero) | Out-Null
        }
    })

    # X button
    $btnX = New-Object System.Windows.Forms.Button
    $btnX.Text = "✕"; $btnX.Size = New-Object System.Drawing.Size(28,28)
    $btnX.Location = New-Object System.Drawing.Point(($wh.ClientSize.Width - 32), 6)
    $btnX.FlatStyle = 'Flat'; $btnX.FlatAppearance.BorderSize = 0
    $btnX.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(70,200,60,60)
    $btnX.BackColor = [System.Drawing.Color]::Transparent; $btnX.ForeColor = $titleC
    $btnX.Font = New-Object System.Drawing.Font('Segoe UI',9); $btnX.Cursor = [System.Windows.Forms.Cursors]::Hand
    $wh.Controls.Add($btnX); $btnX.Add_Click({ $wh.Close() })

    # Przycisk czyszczenia historii
    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text = "Wyczyść historię"
    $btnClear.Location = New-Object System.Drawing.Point(12, 380)
    $btnClear.Size = New-Object System.Drawing.Size(330, 26)
    $btnClear.FlatStyle = 'Flat'; $btnClear.FlatAppearance.BorderSize = 0
    $btnClear.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(40,200,60,60)
    $btnClear.BackColor = [System.Drawing.Color]::Transparent
    $btnClear.ForeColor = [System.Drawing.Color]::FromArgb(160,200,80,80)
    $btnClear.Font = New-Object System.Drawing.Font('Segoe UI',8.5); $btnClear.Cursor = [System.Windows.Forms.Cursors]::Hand
    $wh.Controls.Add($btnClear)

    # Panel scrollowalny z wpisami historii
    $flow = New-Object DBFlowPanel
    $flow.Location = New-Object System.Drawing.Point(10, 48)
    $flow.Size = New-Object System.Drawing.Size(334, 324)
    $flow.AutoScroll = $true; $flow.FlowDirection = 'TopDown'
    $flow.WrapContents = $false; $flow.BackColor = [System.Drawing.Color]::Transparent
    $wh.Controls.Add($flow)

    $inputBgARGB = $inputBg.ToArgb()
    $inputFgARGB = $inputFg.ToArgb()
    $doneARGB    = $doneC.ToArgb()
    $delARGB     = $delC.ToArgb()

    $buildHistory = {
        $flow.Controls.Clear()
        $history = Get-TodoHistory
        if ($history.Count -eq 0) {
            $lbl = New-Object System.Windows.Forms.Label
            $lbl.Text = "Brak wpisów w historii."; $lbl.AutoSize = $true
            $lbl.BackColor = [System.Drawing.Color]::Transparent
            $lbl.ForeColor = [System.Drawing.Color]::FromArgb($inputFgARGB)
            $lbl.Font = New-Object System.Drawing.Font('Segoe UI',9)
            $lbl.Margin = New-Object System.Windows.Forms.Padding(4,8,4,0)
            $flow.Controls.Add($lbl)
            return
        }
        foreach ($entry in $history) {
            $card = New-Object DBPanel
            $card.Size = New-Object System.Drawing.Size(318, 56)
            $card.BackColor = [System.Drawing.Color]::FromArgb($inputBgARGB)
            $card.Margin = New-Object System.Windows.Forms.Padding(2,2,2,2)

            # Ikona statusu
            $lblIcon = New-Object System.Windows.Forms.Label
            $lblIcon.Text = if ($entry.Reason -eq "ukonczono") { "✓" } else { "×" }
            $lblIcon.Location = New-Object System.Drawing.Point(6,4)
            $lblIcon.Size = New-Object System.Drawing.Size(18,18)
            $lblIcon.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
            $lblIcon.BackColor = [System.Drawing.Color]::Transparent
            $lblIcon.ForeColor = if ($entry.Reason -eq "ukonczono") { [System.Drawing.Color]::FromArgb($doneARGB) } else { [System.Drawing.Color]::FromArgb($delARGB) }
            $card.Controls.Add($lblIcon)

            # Nazwa zadania
            $lblText = New-Object System.Windows.Forms.Label
            $lblText.Text = "$($entry.Text)"
            $lblText.Location = New-Object System.Drawing.Point(26,4)
            $lblText.Size = New-Object System.Drawing.Size(280,18)
            $lblText.Font = New-Object System.Drawing.Font('Segoe UI',9)
            $lblText.BackColor = [System.Drawing.Color]::Transparent
            $lblText.ForeColor = [System.Drawing.Color]::FromArgb($inputFgARGB)
            $card.Controls.Add($lblText)

            # Data dodania i archiwizacji
            $meta = "Dodano: $($entry.CreatedAt)   Zarchiwizowano: $($entry.ArchivedAt)"
            $lblMeta = New-Object System.Windows.Forms.Label
            $lblMeta.Text = $meta
            $lblMeta.Location = New-Object System.Drawing.Point(26,24)
            $lblMeta.Size = New-Object System.Drawing.Size(280,14)
            $lblMeta.Font = New-Object System.Drawing.Font('Segoe UI',7)
            $lblMeta.BackColor = [System.Drawing.Color]::Transparent
            $lblMeta.ForeColor = [System.Drawing.Color]::FromArgb(120, [System.Drawing.Color]::FromArgb($inputFgARGB).R, [System.Drawing.Color]::FromArgb($inputFgARGB).G, [System.Drawing.Color]::FromArgb($inputFgARGB).B)
            $card.Controls.Add($lblMeta)

            # Notatki (jeśli są)
            if (-not [string]::IsNullOrWhiteSpace($entry.Notes)) {
                $lblNotes = New-Object System.Windows.Forms.Label
                $shortNote = if ($entry.Notes.Length -gt 55) { $entry.Notes.Substring(0,52) + "..." } else { $entry.Notes }
                $lblNotes.Text = $shortNote
                $lblNotes.Location = New-Object System.Drawing.Point(26,38)
                $lblNotes.Size = New-Object System.Drawing.Size(280,14)
                $lblNotes.Font = New-Object System.Drawing.Font('Segoe UI',7,[System.Drawing.FontStyle]::Italic)
                $lblNotes.BackColor = [System.Drawing.Color]::Transparent
                $lblNotes.ForeColor = [System.Drawing.Color]::FromArgb(140, [System.Drawing.Color]::FromArgb($inputFgARGB).R, [System.Drawing.Color]::FromArgb($inputFgARGB).G, [System.Drawing.Color]::FromArgb($inputFgARGB).B)
                $card.Controls.Add($lblNotes)
                $card.Size = New-Object System.Drawing.Size(318, 58)
            }

            $flow.Controls.Add($card)
        }
    }

    & $buildHistory

    $btnClear.Add_Click({
        $res = [System.Windows.Forms.MessageBox]::Show("Czy na pewno chcesz wyczyścić całą historię?","Historia",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
        if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {
            @() | ConvertTo-Json | Set-Content $script:historyFile -Encoding UTF8
            & $buildHistory
        }
    })

    $wh.ShowDialog($form) | Out-Null; $wh.Dispose()
}

function Show-TodoDetailWindow {
    param([DBPanel]$row)

    $cb = $row.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | Select-Object -First 1
    if (-not $cb) { return }
    $taskText = $cb.Text
    $tagObj = $row.Tag
    $currentNotes = if ($tagObj -is [PSCustomObject] -and $tagObj.Notes) { $tagObj.Notes } else { "" }

    # Kolory zgodne z motywem
    $thm = if ($form.Tag -is [int]) { $form.Tag } else { 0 }
    switch ($thm) {
        1 { $bgTop=[System.Drawing.Color]::FromArgb(36,36,36); $bgBot=[System.Drawing.Color]::FromArgb(18,18,18)
            $borderC=[System.Drawing.Color]::FromArgb(80,120,120,120); $titleC=[System.Drawing.Color]::FromArgb(200,200,200)
            $inputBg=[System.Drawing.Color]::FromArgb(46,46,46); $inputFg=[System.Drawing.Color]::FromArgb(200,200,200)
            $btnBg=[System.Drawing.Color]::FromArgb(50,50,50); $btnFg=[System.Drawing.Color]::FromArgb(190,190,190)
            $btnBord=[System.Drawing.Color]::FromArgb(90,90,90); $btnHov=[System.Drawing.Color]::FromArgb(64,64,64) }
        2 { $bgTop=[System.Drawing.Color]::FromArgb(240,240,240); $bgBot=[System.Drawing.Color]::FromArgb(220,220,220)
            $borderC=[System.Drawing.Color]::FromArgb(150,130,130,130); $titleC=[System.Drawing.Color]::FromArgb(50,50,50)
            $inputBg=[System.Drawing.Color]::FromArgb(250,250,250); $inputFg=[System.Drawing.Color]::FromArgb(50,50,50)
            $btnBg=[System.Drawing.Color]::FromArgb(210,210,210); $btnFg=[System.Drawing.Color]::FromArgb(40,40,40)
            $btnBord=[System.Drawing.Color]::FromArgb(130,130,130); $btnHov=[System.Drawing.Color]::FromArgb(192,192,192) }
        3 { $bgTop=[System.Drawing.Color]::FromArgb(22,35,50); $bgBot=[System.Drawing.Color]::FromArgb(14,24,38)
            $borderC=[System.Drawing.Color]::FromArgb(80,80,130,180); $titleC=[System.Drawing.Color]::FromArgb(190,220,245)
            $inputBg=[System.Drawing.Color]::FromArgb(25,40,55); $inputFg=[System.Drawing.Color]::FromArgb(190,220,245)
            $btnBg=[System.Drawing.Color]::FromArgb(35,50,70); $btnFg=[System.Drawing.Color]::FromArgb(180,220,255)
            $btnBord=[System.Drawing.Color]::FromArgb(80,130,180); $btnHov=[System.Drawing.Color]::FromArgb(50,75,105) }
        default { $bgTop=[System.Drawing.Color]::FromArgb(10,18,34); $bgBot=[System.Drawing.Color]::FromArgb(4,9,18)
            $borderC=[System.Drawing.Color]::FromArgb(70,80,200,150); $titleC=[System.Drawing.Color]::FromArgb(180,220,200)
            $inputBg=[System.Drawing.Color]::FromArgb(10,22,38); $inputFg=[System.Drawing.Color]::FromArgb(180,255,200)
            $btnBg=[System.Drawing.Color]::FromArgb(8,20,14); $btnFg=[System.Drawing.Color]::FromArgb(95,215,155)
            $btnBord=[System.Drawing.Color]::FromArgb(70,200,140); $btnHov=[System.Drawing.Color]::FromArgb(14,40,26) }
    }

    $bgTopARGB = $bgTop.ToArgb(); $bgBotARGB = $bgBot.ToArgb()
    $borderARGB = $borderC.ToArgb(); $titleARGB = $titleC.ToArgb()

    $wd = New-Object System.Windows.Forms.Form
    $wd.Text = ""; $wd.Size = New-Object System.Drawing.Size(320, 300)
    $wd.StartPosition = 'CenterParent'; $wd.FormBorderStyle = 'None'
    $wd.MaximizeBox = $false; $wd.MinimizeBox = $false
    $wd.ShowInTaskbar = $false; $wd.BackColor = $bgBot; $wd.Tag = $thm

    $wd.Add_Paint({
        param($s, $e)
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
        $W = $s.ClientSize.Width; $H = $s.ClientSize.Height
        $cTop = [System.Drawing.Color]::FromArgb($bgTopARGB); $cBot2 = [System.Drawing.Color]::FromArgb($bgBotARGB)
        $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush([System.Drawing.Point]::new(0,0),[System.Drawing.Point]::new(0,$H),$cTop,$cBot2)
        $g.FillRectangle($grad, 0,0,$W,$H); $grad.Dispose()
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($borderARGB), 1)
        $g.DrawRectangle($pen, 0,0,($W-1),($H-1)); $pen.Dispose()
        $sepPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($borderARGB), 1)
        $g.DrawLine($sepPen, 1, 40, ($W-2), 40); $sepPen.Dispose()
        $fnt = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($titleARGB))
        $g.DrawString("📋 Plan zadania", $fnt, $br, 12, 12); $fnt.Dispose(); $br.Dispose()
    }.GetNewClosure())

    $wd.Add_MouseDown({
        param($s,$e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $e.Y -lt 40) {
            [WinAPI]::ReleaseCapture() | Out-Null
            [WinAPI]::SendMessage($s.Handle,[WinAPI]::WM_NCLBUTTONDOWN,[IntPtr][WinAPI]::HTCAPTION,[IntPtr]::Zero) | Out-Null
        }
    })

    # Tytuł zadania
    $lblTask = New-Object System.Windows.Forms.Label
    $lblTask.Text = $taskText; $lblTask.Location = New-Object System.Drawing.Point(12, 50)
    $lblTask.Size = New-Object System.Drawing.Size(284, 20)
    $lblTask.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $lblTask.BackColor = [System.Drawing.Color]::Transparent; $lblTask.ForeColor = $titleC
    $wd.Controls.Add($lblTask)

    # Notatki / plan
    $txtNotes = New-Object System.Windows.Forms.TextBox
    $txtNotes.Location = New-Object System.Drawing.Point(12, 76)
    $txtNotes.Size = New-Object System.Drawing.Size(286, 158)
    $txtNotes.Multiline = $true; $txtNotes.ScrollBars = 'Vertical'
    $txtNotes.BorderStyle = 'FixedSingle'
    $txtNotes.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $txtNotes.BackColor = $inputBg; $txtNotes.ForeColor = $inputFg
    $txtNotes.Text = $currentNotes
    $wd.Controls.Add($txtNotes)

    # Przyciski
    $mkBtn = {
        param([string]$t, [int]$x)
        $b = New-Object System.Windows.Forms.Button; $b.Text = $t
        $b.Location = New-Object System.Drawing.Point($x, 244); $b.Size = New-Object System.Drawing.Size(130, 30)
        $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0
        $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(30, 180, 180, 180)
        $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(60, 180, 180, 180)
        $b.BackColor = [System.Drawing.Color]::Transparent; $b.ForeColor = $titleC
        $b.Font = New-Object System.Drawing.Font('Segoe UI', 9); $b.Cursor = [System.Windows.Forms.Cursors]::Hand
        return $b
    }

    $btnSave = & $mkBtn "Zapisz" 12
    $btnClose = & $mkBtn "Zamknij" 152
    $wd.Controls.Add($btnSave); $wd.Controls.Add($btnClose)

    $btnClose.Add_Click({ $wd.Close() })
    $btnSave.Add_Click({
        $newNotes = $txtNotes.Text
        $tagObj2 = $row.Tag
        if ($tagObj2 -is [PSCustomObject]) {
            $tagObj2.Notes = $newNotes
            $row.Tag = $tagObj2
        } else {
            $row.Tag = [PSCustomObject]@{ CreatedAt = "$tagObj2"; Notes = $newNotes }
        }
        Save-TodoItems
        $wd.Close()
    })

    # X button
    $btnX = New-Object System.Windows.Forms.Button
    $btnX.Text = "✕"; $btnX.Size = New-Object System.Drawing.Size(28,28)
    $btnX.Location = New-Object System.Drawing.Point(($wd.ClientSize.Width - 32), 6)
    $btnX.FlatStyle = 'Flat'; $btnX.FlatAppearance.BorderSize = 0
    $btnX.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(70,200,60,60)
    $btnX.BackColor = [System.Drawing.Color]::Transparent; $btnX.ForeColor = $titleC
    $btnX.Font = New-Object System.Drawing.Font('Segoe UI', 9); $btnX.Cursor = [System.Windows.Forms.Cursors]::Hand
    $wd.Controls.Add($btnX); $btnX.Add_Click({ $wd.Close() })

    $wd.Add_Shown({
        $txtNotes.SelectionStart = $txtNotes.Text.Length
        $txtNotes.SelectionLength = 0
        $txtNotes.Focus()
    })

    $wd.ShowDialog($form) | Out-Null; $wd.Dispose()
}

function Add-TodoRow {
    param([string]$text, [bool]$done = $false, [bool]$save = $true, [string]$createdAt = "", [string]$notes = "")
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    if ([string]::IsNullOrWhiteSpace($createdAt)) { $createdAt = Get-Date -Format 'dd.MM.yy HH:mm' }

    $row = New-Object DBPanel
    $row.Size = New-Object System.Drawing.Size(278, 26)
    $row.BackColor = [System.Drawing.Color]::Transparent
    $row.Tag = [PSCustomObject]@{ CreatedAt = $createdAt; Notes = $notes }

    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $text; $cb.Checked = $done
    $cb.Location = New-Object System.Drawing.Point(2, 3)
    $cb.Size = New-Object System.Drawing.Size(158, 20)
    $cb.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $cb.BackColor = [System.Drawing.Color]::Transparent
    $cb.ForeColor = if ($done) { [System.Drawing.Color]::FromArgb(130, 130, 130) } else { $script:todoForeColor }
    $cb.FlatStyle = 'Flat'
    $cb.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cb.Add_CheckedChanged({
        if ($this.Checked) {
            $this.ForeColor = [System.Drawing.Color]::FromArgb(130, 130, 130)
            $parentRow2 = $this.Parent
            $tagObj3 = $parentRow2.Tag
            $cat = if ($tagObj3 -is [PSCustomObject] -and $tagObj3.CreatedAt) { $tagObj3.CreatedAt } else { "$tagObj3" }
            $nat = if ($tagObj3 -is [PSCustomObject] -and $tagObj3.Notes)     { $tagObj3.Notes }     else { "" }
            Add-ToHistory -text $this.Text -done $true -createdAt $cat -notes $nat -reason "ukonczono"
        } else {
            $this.ForeColor = $script:todoForeColor
        }
        Save-TodoItems
    })
    Enable-DoubleBuffer $cb

    # Przycisk notatek — kliknięcie otwiera okno planu zadania
    $btnNote = New-Object System.Windows.Forms.Button
    $btnNote.Text = "..."; $btnNote.Size = New-Object System.Drawing.Size(20, 20)
    $btnNote.Location = New-Object System.Drawing.Point(162, 3)
    $btnNote.FlatStyle = 'Flat'; $btnNote.FlatAppearance.BorderSize = 0
    $btnNote.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(40, 100, 200, 255)
    $btnNote.BackColor = [System.Drawing.Color]::Transparent
    $btnNote.ForeColor = [System.Drawing.Color]::FromArgb(160, 120, 200, 255)
    $btnNote.Font = New-Object System.Drawing.Font('Segoe UI', 8); $btnNote.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnNote.Add_Click({ Show-TodoDetailWindow -row $this.Parent })
    Enable-DoubleBuffer $btnNote

    $lblDate = New-Object System.Windows.Forms.Label
    $lblDate.Text = $createdAt
    $lblDate.Location = New-Object System.Drawing.Point(184, 5)
    $lblDate.Size = New-Object System.Drawing.Size(64, 16)
    $lblDate.Font = New-Object System.Drawing.Font('Segoe UI', 7)
    $lblDate.BackColor = [System.Drawing.Color]::Transparent
    $lblDate.ForeColor = [System.Drawing.Color]::FromArgb(100, $script:todoForeColor.R, $script:todoForeColor.G, $script:todoForeColor.B)
    $lblDate.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    Enable-DoubleBuffer $lblDate

    $btnDel = New-Object System.Windows.Forms.Button
    $btnDel.Text = "×"; $btnDel.Size = New-Object System.Drawing.Size(20, 20)
    $btnDel.Location = New-Object System.Drawing.Point(252, 3)
    $btnDel.FlatStyle = 'Flat'; $btnDel.FlatAppearance.BorderSize = 0
    $btnDel.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(60, 200, 60, 60)
    $btnDel.BackColor = [System.Drawing.Color]::Transparent
    $btnDel.ForeColor = [System.Drawing.Color]::FromArgb(180, 200, 80, 80)
    $btnDel.Font = New-Object System.Drawing.Font('Segoe UI', 10); $btnDel.Cursor = [System.Windows.Forms.Cursors]::Hand
    Enable-DoubleBuffer $btnDel

    $btnDel.Add_Click({
        $parentRow = $this.Parent
        $cbDel = $parentRow.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | Select-Object -First 1
        if ($cbDel) {
            $tagObjD = $parentRow.Tag
            $catD = if ($tagObjD -is [PSCustomObject] -and $tagObjD.CreatedAt) { $tagObjD.CreatedAt } else { "$tagObjD" }
            $natD = if ($tagObjD -is [PSCustomObject] -and $tagObjD.Notes)     { $tagObjD.Notes }     else { "" }
            Add-ToHistory -text $cbDel.Text -done $cbDel.Checked -createdAt $catD -notes $natD -reason "usunieto"
        }
        $script:todoFlow.Controls.Remove($parentRow)
        $parentRow.Dispose()
        Save-TodoItems
    })

    $row.Controls.Add($cb); $row.Controls.Add($btnNote); $row.Controls.Add($lblDate); $row.Controls.Add($btnDel)
    $script:todoFlow.Controls.Add($row)
    if ($save) { Save-TodoItems }
}

function Rebuild-TodoList {
    $script:todoFlow.Controls.Clear()
    foreach ($item in (Get-TodoItems)) {
        $itemNotes = if ($item.Notes) { "$($item.Notes)" } else { "" }
        Add-TodoRow -text $item.Text -done ([bool]$item.Done) -createdAt "$($item.CreatedAt)" -notes $itemNotes -save $false
    }
}

function Apply-TodoTheme {
    param(
        [System.Drawing.Color]$headerColor,
        [System.Drawing.Color]$inputBg,
        [System.Drawing.Color]$inputFg,
        [System.Drawing.Color]$btnBg,
        [System.Drawing.Color]$btnFg,
        [System.Drawing.Color]$btnBorder,
        [System.Drawing.Color]$btnHover
    )
    $script:lblTodo.ForeColor = $headerColor
    $script:txtTodoInput.BackColor = $inputBg; $script:txtTodoInput.ForeColor = $inputFg
    $script:btnTodoAdd.BackColor = $btnBg; $script:btnTodoAdd.ForeColor = $btnFg
    $script:btnTodoAdd.FlatAppearance.BorderColor = $btnBorder
    $script:btnTodoAdd.FlatAppearance.MouseOverBackColor = $btnHover
    $script:todoForeColor = $inputFg
    foreach ($row in $script:todoFlow.Controls) {
        if ($row -is [DBPanel]) {
            $cb = $row.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | Select-Object -First 1
            if ($cb) { $cb.ForeColor = if ($cb.Checked) { [System.Drawing.Color]::FromArgb(130, 130, 130) } else { $inputFg } }
            $lbl = $row.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] } | Select-Object -First 1
            if ($lbl) { $lbl.ForeColor = [System.Drawing.Color]::FromArgb(100, $inputFg.R, $inputFg.G, $inputFg.B) }
        }
    }
}

# Kontener
$script:todoPanel = New-Object DBPanel
$script:todoPanel.Location = New-Object System.Drawing.Point(48, 195)
$script:todoPanel.Size = New-Object System.Drawing.Size(305, 215)
$script:todoPanel.BackColor = [System.Drawing.Color]::Transparent
$script:homePanel.Controls.Add($script:todoPanel)

# Nagłówek
$script:lblTodo = New-Object System.Windows.Forms.Label
$script:lblTodo.Text = "✓ To-Do"
$script:lblTodo.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$script:lblTodo.Location = New-Object System.Drawing.Point(0, 0)
$script:lblTodo.AutoSize = $true
$script:lblTodo.BackColor = [System.Drawing.Color]::Transparent
$script:lblTodo.ForeColor = [System.Drawing.Color]::FromArgb(140, 255, 190)
$script:todoPanel.Controls.Add($script:lblTodo)

# Przycisk "Historia"
$script:btnTodoHistory = New-Object System.Windows.Forms.Button
$script:btnTodoHistory.Text = "Historia"
$script:btnTodoHistory.Location = New-Object System.Drawing.Point(200, 0)
$script:btnTodoHistory.Size = New-Object System.Drawing.Size(90, 20)
$script:btnTodoHistory.FlatStyle = 'Flat'; $script:btnTodoHistory.FlatAppearance.BorderSize = 0
$script:btnTodoHistory.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(30, 180, 180, 180)
$script:btnTodoHistory.BackColor = [System.Drawing.Color]::Transparent
$script:btnTodoHistory.ForeColor = [System.Drawing.Color]::FromArgb(95, 215, 155)
$script:btnTodoHistory.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$script:btnTodoHistory.Cursor = [System.Windows.Forms.Cursors]::Hand
$script:btnTodoHistory.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$script:todoPanel.Controls.Add($script:btnTodoHistory)
$script:btnTodoHistory.Add_Click({ Show-TodoHistoryWindow })

# Pole tekstowe nowego zadania
$script:txtTodoInput = New-Object System.Windows.Forms.TextBox
$script:txtTodoInput.Location = New-Object System.Drawing.Point(0, 28)
$script:txtTodoInput.Size = New-Object System.Drawing.Size(256, 24)
$script:txtTodoInput.BorderStyle = 'FixedSingle'
$script:txtTodoInput.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$script:txtTodoInput.BackColor = [System.Drawing.Color]::FromArgb(10, 18, 34)
$script:txtTodoInput.ForeColor = [System.Drawing.Color]::FromArgb(180, 255, 200)
$script:todoPanel.Controls.Add($script:txtTodoInput)

# Przycisk "+"
$script:btnTodoAdd = New-Object System.Windows.Forms.Button
$script:btnTodoAdd.Text = "+"; $script:btnTodoAdd.Location = New-Object System.Drawing.Point(262, 27)
$script:btnTodoAdd.Size = New-Object System.Drawing.Size(28, 26); $script:btnTodoAdd.FlatStyle = 'Flat'
$script:btnTodoAdd.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 200, 140)
$script:btnTodoAdd.FlatAppearance.BorderSize = 1
$script:btnTodoAdd.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(14, 40, 26)
$script:btnTodoAdd.BackColor = [System.Drawing.Color]::FromArgb(8, 20, 14)
$script:btnTodoAdd.ForeColor = [System.Drawing.Color]::FromArgb(95, 215, 155)
$script:btnTodoAdd.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$script:btnTodoAdd.Cursor = [System.Windows.Forms.Cursors]::Hand
$script:todoPanel.Controls.Add($script:btnTodoAdd)

# Lista zadań (scrollowalna)
$script:todoFlow = New-Object DBFlowPanel
$script:todoFlow.Location = New-Object System.Drawing.Point(0, 60)
$script:todoFlow.Size = New-Object System.Drawing.Size(300, 152)
$script:todoFlow.AutoScroll = $true
$script:todoFlow.FlowDirection = 'TopDown'
$script:todoFlow.WrapContents = $false
$script:todoFlow.BackColor = [System.Drawing.Color]::Transparent
$script:todoPanel.Controls.Add($script:todoFlow)

# Eventy
$script:btnTodoAdd.Add_Click({
    Add-TodoRow -text $script:txtTodoInput.Text.Trim()
    $script:txtTodoInput.Text = ''; $script:txtTodoInput.Focus()
})
$script:txtTodoInput.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Return) {
        Add-TodoRow -text $script:txtTodoInput.Text.Trim()
        $script:txtTodoInput.Text = ''; $e.SuppressKeyPress = $true
    }
})

Rebuild-TodoList

$script:lblTopApps = New-Object System.Windows.Forms.Label
$script:lblTopApps.Text = "Często otwierane"
$script:lblTopApps.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$script:lblTopApps.AutoSize = $true
$script:lblTopApps.Location = New-Object System.Drawing.Point(380, 165)
Enable-DoubleBuffer $script:lblTopApps
$script:homePanel.Controls.Add($script:lblTopApps)

$script:topAppsPanel = New-Object DBFlowPanel
$script:topAppsPanel.Location = New-Object System.Drawing.Point(375, 200)
$script:topAppsPanel.Size = New-Object System.Drawing.Size(345, 210)
$script:topAppsPanel.AutoScroll = $true
$script:homePanel.Controls.Add($script:topAppsPanel)

function Refresh-DashboardTopApps {
    $script:topAppsPanel.Controls.Clear()
    $apps = @(Get-AppConfig) | Where-Object { $_.LaunchCount -gt 0 } | Sort-Object LaunchCount -Descending | Select-Object -First 3
    foreach ($a in $apps) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Size = New-Object System.Drawing.Size(330, 46)
        $btn.FlatStyle = 'Flat'
        $btn.FlatAppearance.BorderSize = 0
        $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::Transparent
        $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::Transparent
        $btn.BackColor = [System.Drawing.Color]::Transparent
        $btn.ForeColor = [System.Drawing.Color]::Transparent
        $btn.Text = ""; $btn.Cursor = [System.Windows.Forms.Cursors]::Hand

        $appName = $a.Name; $appPath = $a.Path; $appTheme = $script:currentTheme
        $absIcon = ConvertTo-AbsolutePath $a.IconFile
        $appIconImg = $null
        if ($absIcon -and (Test-Path $absIcon)) {
            try { $img = [System.Drawing.Image]::FromFile($absIcon); $appIconImg = $img.GetThumbnailImage(28, 28, $null, [intptr]::Zero); $img.Dispose() } catch {}
        }
        $btn.Tag = @{ hover = $false; path = $appPath; icon = $appIconImg; name = $appName; theme = $appTheme }

        $btn.Add_MouseEnter({ $this.Tag.hover = $true;  $this.Invalidate() })
        $btn.Add_MouseLeave({ $this.Tag.hover = $false; $this.Invalidate() })

        $btn.Add_Paint({
            param($s, $e)
            $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
            $st = $s.Tag; $isH = $st.hover; $W = $s.Width; $H = $s.Height

            $rect = New-Object System.Drawing.Rectangle(1, 1, ($W - 3), ($H - 3))
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $r = 8; $d = $r * 2
            $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
            $path.AddArc(($rect.Right - $d), $rect.Y, $d, $d, 270, 90)
            $path.AddArc(($rect.Right - $d), ($rect.Bottom - $d), $d, $d, 0, 90)
            $path.AddArc($rect.X, ($rect.Bottom - $d), $d, $d, 90, 90)
            $path.CloseFigure()

            $bgAlpha  = if ($isH) { 85  } else { 45  }
            $penAlpha = if ($isH) { 160 } else { 70  }
            $txtAlpha = if ($isH) { 230 } else { 180 }
            switch ($st.theme) {
                1 { $bgC  = [System.Drawing.Color]::FromArgb($bgAlpha,  60,  60,  60)
                    $penC = [System.Drawing.Color]::FromArgb($penAlpha, 130, 130, 130)
                    $txtC = [System.Drawing.Color]::FromArgb($txtAlpha, 200, 200, 200) }
                2 { $bgC  = [System.Drawing.Color]::FromArgb($(if($isH){190}else{120}), 200, 200, 200)
                    $penC = [System.Drawing.Color]::FromArgb($(if($isH){210}else{110}),  80,  80,  80)
                    $txtC = [System.Drawing.Color]::FromArgb(40, 40, 40) }
                3 { $bgC  = [System.Drawing.Color]::FromArgb($(if($isH){ 95}else{ 50}),  80, 120, 170)
                    $penC = [System.Drawing.Color]::FromArgb($(if($isH){185}else{ 85}), 130, 180, 230)
                    $txtC = [System.Drawing.Color]::FromArgb($(if($isH){255}else{210}), 210, 235, 255) }
                default { $bgC  = [System.Drawing.Color]::FromArgb($(if($isH){ 75}else{ 38}),  12,  44,  26)
                          $penC = [System.Drawing.Color]::FromArgb($(if($isH){185}else{ 78}),  80, 210, 150)
                          $txtC = [System.Drawing.Color]::FromArgb($(if($isH){245}else{185}), 120, 255, 180) }
            }

            $br = New-Object System.Drawing.SolidBrush($bgC)
            $pn = New-Object System.Drawing.Pen($penC, 1.2)
            $g.FillPath($br, $path); $g.DrawPath($pn, $path)

            if ($st.icon -ne $null) {
                $iconY = [int](($H - 28) / 2)
                $g.DrawImage($st.icon, 10, $iconY, 28, 28)
            } else {
                $phBr = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 150, 150, 150))
                $g.FillEllipse($phBr, 10, [int](($H - 28) / 2), 28, 28); $phBr.Dispose()
            }

            $sf = New-Object System.Drawing.StringFormat
            $sf.Alignment = 'Near'; $sf.LineAlignment = 'Center'; $sf.Trimming = 'EllipsisCharacter'
            $tF = New-Object System.Drawing.Font('Segoe UI', 9.5)
            $tBr = New-Object System.Drawing.SolidBrush($txtC)
            $g.DrawString($st.name, $tF, $tBr, ([System.Drawing.RectangleF]::new(48, 0, ($W - 58), $H)), $sf)

            $br.Dispose(); $pn.Dispose(); $sf.Dispose(); $tF.Dispose(); $tBr.Dispose(); $path.Dispose()
        }.GetNewClosure())

        $btn.Add_Click({
            try { Start-Process $this.Tag.path; Increment-AppLaunchCount -path $this.Tag.path } catch {}
        })
        $script:topAppsPanel.Controls.Add($btn)
    }
}
Refresh-DashboardTopApps

$script:clockTimer = New-Object System.Windows.Forms.Timer
$script:clockTimer.Interval = 1000
$script:clockTimer.Add_Tick({
    $script:lblClock.Text = (Get-Date).ToString("HH:mm")
    $script:lblDate.Text = (Get-Date).ToString("dddd, d MMMM yyyy")
})
$script:clockTimer.Start()
$script:lblClock.Text = (Get-Date).ToString("HH:mm")
$script:lblDate.Text = (Get-Date).ToString("dddd, d MMMM yyyy")

$script:weatherClient = New-Object System.Net.WebClient
$script:weatherClient.Encoding = [System.Text.Encoding]::UTF8
$script:weatherClient.Headers.Add("Accept-Language", "pl")
$script:weatherClient.add_DownloadStringCompleted({
    param($sender, $e)
    if (-not $e.Error -and -not $e.Cancelled) {
        $res = $e.Result.Trim()
        if ($res -match "Unknown location") { $script:lblWeather.Text = "Nieznane miasto" }
        else { $script:lblWeather.Text = $res }
    } else {
        $script:lblWeather.Text = "Brak danych o pogodzie"
    }
})

function Update-Weather {
    $city = (Get-Settings).City
    if ([string]::IsNullOrWhiteSpace($city)) {
        $script:lblWeather.Text = "Ustaw miasto w opcjach"
        return
    }
    try {
        $url = "https://wttr.in/$([uri]::EscapeDataString($city))?format=`"%c+%t,+%C`""
        $script:weatherClient.DownloadStringAsync([uri]$url)
    } catch { }
}
Update-Weather

# ===========================================================
#   Pasek Boczny / Form UI (Dalsza część)
# ===========================================================

$script:sidebarPanel = New-Object DBPanel
$script:sidebarPanel.Location  = New-Object System.Drawing.Point(-$script:sidebarWidth, 57)
$script:sidebarPanel.Size      = New-Object System.Drawing.Size($script:sidebarWidth, ($form.Height - 57 - 55))
$script:sidebarPanel.Anchor    = 'Top, Left, Bottom'
$script:sidebarPanel.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($script:sidebarPanel)

$script:sidebarPanel.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = 'AntiAlias'
    
    $theme = $script:currentTheme
    
    switch ($theme) {
        1 { $bgC  = [System.Drawing.Color]::FromArgb(45, 60, 60, 60)
            $penC = [System.Drawing.Color]::FromArgb(70, 130, 130, 130) }
        2 { $bgC  = [System.Drawing.Color]::FromArgb(120, 200, 200, 200)
            $penC = [System.Drawing.Color]::FromArgb(110, 80, 80, 80) }
        3 { $bgC  = [System.Drawing.Color]::FromArgb(50, 80, 120, 170)
            $penC = [System.Drawing.Color]::FromArgb(85, 130, 180, 230) }
        default { 
            $bgC  = [System.Drawing.Color]::FromArgb(38, 12, 44, 26)
            $penC = [System.Drawing.Color]::FromArgb(78, 80, 210, 150) 
        }
    }
    
    $W = $s.Width; $H = $s.Height
    $rect = New-Object System.Drawing.Rectangle(0, 0, ($W - 1), ($H - 1))
    
    $br = New-Object System.Drawing.SolidBrush($bgC)
    $pn = New-Object System.Drawing.Pen($penC, 1.2)
    
    $g.FillRectangle($br, $rect)
    $g.DrawRectangle($pn, $rect)
    
    $br.Dispose()
    $pn.Dispose()
})

$sidebarSep = New-Object System.Windows.Forms.Panel
$sidebarSep.Location  = New-Object System.Drawing.Point($script:sidebarWidth, 57)
$sidebarSep.Size      = New-Object System.Drawing.Size(1, ($form.Height - 57 - 55))
$sidebarSep.Anchor    = 'Top, Left, Bottom'
$sidebarSep.BackColor = [System.Drawing.Color]::FromArgb(18, 52, 38)
$sidebarSep.Visible   = $false
$form.Controls.Add($sidebarSep)

$script:sidebarIndicator = New-Object System.Windows.Forms.Panel
$script:sidebarIndicator.Location  = New-Object System.Drawing.Point(0, 57)
$script:sidebarIndicator.Size      = New-Object System.Drawing.Size(4, ($form.Height - 57 - 55))
$script:sidebarIndicator.Anchor    = 'Top, Left, Bottom'
$script:sidebarIndicator.BackColor = [System.Drawing.Color]::FromArgb(28, 72, 45)
$script:sidebarIndicator.Cursor    = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($script:sidebarIndicator)
$script:sidebarIndicator.BringToFront()

$script:sidebarTargetX    = -$script:sidebarWidth
$script:sidebarCurrentX   = [double](-$script:sidebarWidth)
$script:sidebarCheckTick  = 0
$script:sidebarHideTicks  = -1
$script:sidebarHideDelay  = 21
$script:sidebarPinned     = $false

$script:sidebarAnimTimer = New-Object System.Windows.Forms.Timer
$script:sidebarAnimTimer.Interval = 20
$script:sidebarReachedTarget = $false

$script:sidebarAnimTimer.Add_Tick({
    $tgt  = [double]$script:sidebarTargetX
    $script:sidebarCurrentX += ($tgt - $script:sidebarCurrentX) * 0.35
    $rounded = [int][Math]::Round($script:sidebarCurrentX)
    $diff    = [Math]::Abs($tgt - $script:sidebarCurrentX)

    if ($diff -gt 0.5) {
        $script:sidebarPanel.Left = $rounded
        $script:sidebarReachedTarget = $false
    } else {
        $script:sidebarPanel.Left = [int]$tgt
        if (-not $script:sidebarReachedTarget) {
            $script:sidebarReachedTarget = $true
            $form.ResumeLayout($false)
            if ($tgt -lt 0) {
                $sidebarSep.Visible = $false; $script:sidebarIndicator.Visible = $true
                $script:sidebarIndicator.BringToFront(); $script:sidebarHideTicks = -1
                $script:sidebarAnimTimer.Stop()
                Invoke-TileLayout
            } else {
                $sidebarSep.Visible = $true; $script:sidebarIndicator.Visible = $false
                Invoke-TileLayout
            }
        }

        if ($tgt -ge 0) {
            $script:sidebarCheckTick++
            if ($script:sidebarCheckTick -ge 6) {
                $script:sidebarCheckTick = 0
                $ptForm = $form.PointToClient([System.Windows.Forms.Cursor]::Position)
                $inZone = ($ptForm.X -ge 0 -and $ptForm.X -le ($script:sidebarWidth + 4) -and $ptForm.Y -ge 57 -and $ptForm.Y -le ($form.Height - 55))
                if ($inZone -or $script:sidebarPinned) { $script:sidebarHideTicks = -1 } else {
                    if ($script:sidebarHideTicks -lt 0) { $script:sidebarHideTicks = $script:sidebarHideDelay }
                    else {
                        $script:sidebarHideTicks--
                        if ($script:sidebarHideTicks -le 0) { $script:sidebarHideTicks = -1; $script:sidebarTargetX = -$script:sidebarWidth; $sidebarSep.Visible = $false; $script:sidebarReachedTarget = $false }
                    }
                }
            }
        }
    }
})

$script:sidebarIndicator.Add_MouseEnter({
    $script:sidebarCurrentX = [double]$script:sidebarPanel.Left; $script:sidebarTargetX = 0
    $script:sidebarReachedTarget = $false
    $script:sidebarPanel.BringToFront()
    $form.SuspendLayout()
    $script:sidebarAnimTimer.Start()
})

$lockBtn = New-Object LockButton
$lockBtn.Size = New-Object System.Drawing.Size(28, 28); $lockBtn.Location = New-Object System.Drawing.Point(($form.Width - 28 - 52), 14)
$lockBtn.Anchor = 'Top, Right'; $form.Controls.Add($lockBtn)

$pinBtn = New-Object PinButton
$pinBtn.Size = New-Object System.Drawing.Size(28, 28); $pinBtn.Location = New-Object System.Drawing.Point(($form.Width - 28 - 52 - 30), 14)
$pinBtn.Anchor = 'Top, Right'; $form.Controls.Add($pinBtn)

if ($null -eq $script:currentTheme) { $script:currentTheme = 0 }

function Apply-Theme {
    param([int]$theme)
    $script:currentTheme = $theme
    $form.Tag = $theme

    if ($theme -eq 3) {
        $form.Opacity = 0.95
        $form.BackColor = [System.Drawing.Color]::FromArgb(15, 25, 35)
    } else {
        $form.Opacity = 1.0
        switch ($theme) {
            0 { $form.BackColor = [System.Drawing.Color]::FromArgb(3,  8,  16) }
            1 { $form.BackColor = [System.Drawing.Color]::FromArgb(26, 26, 26) }
            2 { $form.BackColor = [System.Drawing.Color]::FromArgb(238, 238, 238) }
        }
    }

    try { $form.RebuildCachePublic() } catch {
        $s = $form.Size; $form.Size = New-Object System.Drawing.Size(($s.Width + 1), $s.Height); $form.Size = $s
    }
    $form.Invalidate()

    switch ($theme) {
        0 { # Aurora
            $bottomPanel.BackColor          = [System.Drawing.Color]::FromArgb(4, 9, 18)
            $sidebarSep.BackColor           = [System.Drawing.Color]::FromArgb(18, 52, 38)
            if ($script:sidebarIndicator) { $script:sidebarIndicator.BackColor = [System.Drawing.Color]::FromArgb(28, 72, 45) }
            $script:searchBox.BackColor     = [System.Drawing.Color]::FromArgb(8, 18, 32)
            if ($script:searchPlaceholder)  { $script:searchBox.ForeColor = [System.Drawing.Color]::FromArgb(65, 110, 90) }
            else                            { $script:searchBox.ForeColor = [System.Drawing.Color]::FromArgb(140, 255, 190) }
            $lblSize.ForeColor              = [System.Drawing.Color]::FromArgb(110, 120, 200, 160)
            $lblSizeVal.ForeColor           = [System.Drawing.Color]::FromArgb(110, 100, 255, 180)
            $script:btnSettings.BackColor = [System.Drawing.Color]::Transparent
            $script:btnSettings.ForeColor = [System.Drawing.Color]::FromArgb(95, 215, 155)
            $script:btnSettings.FlatAppearance.BorderSize = 0
            $script:btnSettings.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(30, 180, 180, 180)
            
            # Kolory Dashboardu
            $script:lblClock.ForeColor = [System.Drawing.Color]::FromArgb(255,255,255)
            $script:lblDate.ForeColor = [System.Drawing.Color]::FromArgb(140,255,190)
            $script:lblWeather.ForeColor = [System.Drawing.Color]::FromArgb(100,200,255)
            $script:lblTopApps.ForeColor = [System.Drawing.Color]::FromArgb(140,255,190)
            Apply-TodoTheme -headerColor ([System.Drawing.Color]::FromArgb(140,255,190)) -inputBg ([System.Drawing.Color]::FromArgb(10,18,34)) -inputFg ([System.Drawing.Color]::FromArgb(180,255,200)) -btnBg ([System.Drawing.Color]::FromArgb(8,20,14)) -btnFg ([System.Drawing.Color]::FromArgb(95,215,155)) -btnBorder ([System.Drawing.Color]::FromArgb(70,200,140)) -btnHover ([System.Drawing.Color]::FromArgb(14,40,26))
        }
        1 { # Ciemny
            $bottomPanel.BackColor          = [System.Drawing.Color]::FromArgb(30, 30, 30)
            $sidebarSep.BackColor           = [System.Drawing.Color]::FromArgb(58, 58, 58)
            if ($script:sidebarIndicator) { $script:sidebarIndicator.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 55) }
            $script:searchBox.BackColor     = [System.Drawing.Color]::FromArgb(46, 46, 46)
            if ($script:searchPlaceholder)  { $script:searchBox.ForeColor = [System.Drawing.Color]::FromArgb(105, 105, 105) }
            else                            { $script:searchBox.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200) }
            $lblSize.ForeColor              = [System.Drawing.Color]::FromArgb(145, 145, 145)
            $lblSizeVal.ForeColor           = [System.Drawing.Color]::FromArgb(145, 145, 145)
            $script:btnSettings.BackColor = [System.Drawing.Color]::Transparent
            $script:btnSettings.ForeColor = [System.Drawing.Color]::FromArgb(190, 190, 190)
            $script:btnSettings.FlatAppearance.BorderSize = 0
            $script:btnSettings.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(30, 180, 180, 180)

            # Kolory Dashboardu
            $script:lblClock.ForeColor = [System.Drawing.Color]::FromArgb(220,220,220)
            $script:lblDate.ForeColor = [System.Drawing.Color]::FromArgb(160,160,160)
            $script:lblWeather.ForeColor = [System.Drawing.Color]::FromArgb(180,180,180)
            $script:lblTopApps.ForeColor = [System.Drawing.Color]::FromArgb(180,180,180)
            Apply-TodoTheme -headerColor ([System.Drawing.Color]::FromArgb(180,180,180)) -inputBg ([System.Drawing.Color]::FromArgb(46,46,46)) -inputFg ([System.Drawing.Color]::FromArgb(200,200,200)) -btnBg ([System.Drawing.Color]::FromArgb(50,50,50)) -btnFg ([System.Drawing.Color]::FromArgb(190,190,190)) -btnBorder ([System.Drawing.Color]::FromArgb(90,90,90)) -btnHover ([System.Drawing.Color]::FromArgb(64,64,64))
        }
        2 { # Jasny
            $bottomPanel.BackColor          = [System.Drawing.Color]::FromArgb(218, 218, 218)
            $sidebarSep.BackColor           = [System.Drawing.Color]::FromArgb(165, 165, 165)
            if ($script:sidebarIndicator) { $script:sidebarIndicator.BackColor = [System.Drawing.Color]::FromArgb(185, 185, 185) }
            $script:searchBox.BackColor     = [System.Drawing.Color]::FromArgb(250, 250, 250)
            if ($script:searchPlaceholder)  { $script:searchBox.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150) }
            else                            { $script:searchBox.ForeColor = [System.Drawing.Color]::FromArgb(40,  40,  40)  }
            $lblSize.ForeColor              = [System.Drawing.Color]::FromArgb(60, 60, 60)
            $lblSizeVal.ForeColor           = [System.Drawing.Color]::FromArgb(60, 60, 60)
            $script:btnSettings.BackColor = [System.Drawing.Color]::Transparent
            $script:btnSettings.ForeColor = [System.Drawing.Color]::FromArgb(40,  40,  40)
            $script:btnSettings.FlatAppearance.BorderSize = 0
            $script:btnSettings.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(40, 100, 100, 100)

            # Kolory Dashboardu
            $script:lblClock.ForeColor = [System.Drawing.Color]::FromArgb(40,40,40)
            $script:lblDate.ForeColor = [System.Drawing.Color]::FromArgb(80,80,80)
            $script:lblWeather.ForeColor = [System.Drawing.Color]::FromArgb(60,60,60)
            $script:lblTopApps.ForeColor = [System.Drawing.Color]::FromArgb(60,60,60)
            Apply-TodoTheme -headerColor ([System.Drawing.Color]::FromArgb(60,60,60)) -inputBg ([System.Drawing.Color]::FromArgb(250,250,250)) -inputFg ([System.Drawing.Color]::FromArgb(50,50,50)) -btnBg ([System.Drawing.Color]::FromArgb(210,210,210)) -btnFg ([System.Drawing.Color]::FromArgb(40,40,40)) -btnBorder ([System.Drawing.Color]::FromArgb(130,130,130)) -btnHover ([System.Drawing.Color]::FromArgb(192,192,192))
        }
        3 { # Matowy (Szkło)
            $bottomPanel.BackColor          = [System.Drawing.Color]::FromArgb(15, 25, 35)
            $sidebarSep.BackColor           = [System.Drawing.Color]::FromArgb(40, 60, 80)
            if ($script:sidebarIndicator) { $script:sidebarIndicator.BackColor = [System.Drawing.Color]::FromArgb(80, 150, 200) }
            $script:searchBox.BackColor     = [System.Drawing.Color]::FromArgb(25, 40, 55)
            if ($script:searchPlaceholder)  { $script:searchBox.ForeColor = [System.Drawing.Color]::FromArgb(100, 140, 180) }
            else                            { $script:searchBox.ForeColor = [System.Drawing.Color]::FromArgb(200, 230, 255) }
            $lblSize.ForeColor              = [System.Drawing.Color]::FromArgb(120, 160, 200)
            $lblSizeVal.ForeColor           = [System.Drawing.Color]::FromArgb(180, 220, 255)
            $script:btnSettings.BackColor   = [System.Drawing.Color]::Transparent
            $script:btnSettings.ForeColor   = [System.Drawing.Color]::FromArgb(180, 220, 255)
            $script:btnSettings.FlatAppearance.BorderSize = 0
            $script:btnSettings.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(30, 180, 180, 180)

            # Kolory Dashboardu
            $script:lblClock.ForeColor = [System.Drawing.Color]::FromArgb(230,240,255)
            $script:lblDate.ForeColor = [System.Drawing.Color]::FromArgb(150,200,255)
            $script:lblWeather.ForeColor = [System.Drawing.Color]::FromArgb(180,220,255)
            $script:lblTopApps.ForeColor = [System.Drawing.Color]::FromArgb(150,200,255)
            Apply-TodoTheme -headerColor ([System.Drawing.Color]::FromArgb(150,200,255)) -inputBg ([System.Drawing.Color]::FromArgb(25,40,55)) -inputFg ([System.Drawing.Color]::FromArgb(190,220,245)) -btnBg ([System.Drawing.Color]::FromArgb(35,50,70)) -btnFg ([System.Drawing.Color]::FromArgb(180,220,255)) -btnBorder ([System.Drawing.Color]::FromArgb(80,130,180)) -btnHover ([System.Drawing.Color]::FromArgb(50,75,105))
        }
    }

    $form.Controls | Where-Object { $_ -is [AppTile] } | ForEach-Object { $_.Invalidate() }
    
    # Odświeżenie panelu bocznego dla nowego motywu
    if ($script:sidebarPanel) { $script:sidebarPanel.Invalidate() }
    
    Rebuild-FolderPanel
    Refresh-DashboardTopApps
    Save-Settings -tileSize $script:tileSize -theme $theme
}

$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Location  = New-Object System.Drawing.Point(0, ($form.Height - 55))
$bottomPanel.Size      = New-Object System.Drawing.Size($form.Width, 55)
$bottomPanel.Anchor    = 'Bottom, Left, Right'; $bottomPanel.BackColor = [System.Drawing.Color]::FromArgb(4, 9, 18)
$bottomPanel.Visible   = $true; $form.Controls.Add($bottomPanel)

$sepLine = New-Object System.Windows.Forms.Panel
$sepLine.Location  = New-Object System.Drawing.Point(0, 0); $sepLine.Size = New-Object System.Drawing.Size($form.Width, 1)
$sepLine.Anchor    = 'Left, Right'; $sepLine.BackColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
$sepLine.Visible   = $true; $bottomPanel.Controls.Add($sepLine)

$lblSize = New-Object System.Windows.Forms.Label
$lblSize.Text = "Rozmiar:"; $lblSize.Location = New-Object System.Drawing.Point(16, 18); $lblSize.AutoSize = $true
$lblSize.BackColor = 'Transparent'; $lblSize.ForeColor = [System.Drawing.Color]::FromArgb(110, 120, 200, 160)
$lblSize.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
$bottomPanel.Controls.Add($lblSize); $lblSize.Visible = $false

$sizeSlider = New-Object SimpleSlider
$sizeSlider.Location = New-Object System.Drawing.Point(78, 10); $sizeSlider.Size = New-Object System.Drawing.Size(175, 34)
$sizeSlider.Minimum = 70; $sizeSlider.Maximum = 180; $sizeSlider.Value = $script:tileSize
$bottomPanel.Controls.Add($sizeSlider); $sizeSlider.Visible = $false

$lblSizeVal = New-Object System.Windows.Forms.Label
$lblSizeVal.Text = "$($script:tileSize) px"; $lblSizeVal.Location = New-Object System.Drawing.Point(260, 18)
$lblSizeVal.AutoSize = $true; $lblSizeVal.BackColor = 'Transparent'

$script:searchPlaceholder = $true
$script:searchBox = New-Object System.Windows.Forms.TextBox
$script:searchBox.Size = New-Object System.Drawing.Size(210, 26); $script:searchBox.Location = New-Object System.Drawing.Point(($bottomPanel.Width - 210 - 10), 14)
$script:searchBox.Anchor = 'Bottom, Right'; $script:searchBox.BackColor = [System.Drawing.Color]::FromArgb(8, 18, 32)
$script:searchBox.ForeColor = [System.Drawing.Color]::FromArgb(65, 110, 90); $script:searchBox.BorderStyle = 'FixedSingle'
$script:searchBox.Font = New-Object System.Drawing.Font('Segoe UI', 9); $script:searchBox.Text = '🔍 Szukaj aplikacji...'
$bottomPanel.Controls.Add($script:searchBox)

$script:themeLabels = @("Aurora", "Ciemny", "Jasny", "Matowy (Szkło)")

function Show-SettingsWindow {
    $thm = $script:currentTheme

    switch ($thm) {
        1 { $bgTop = [System.Drawing.Color]::FromArgb(38, 38, 38); $bgBot = [System.Drawing.Color]::FromArgb(22, 22, 22)
            $borderC = [System.Drawing.Color]::FromArgb(80, 100, 100, 100); $sepC = [System.Drawing.Color]::FromArgb(55, 100, 100, 100)
            $titleC = [System.Drawing.Color]::FromArgb(200, 190, 190, 190); $btn_bg = [System.Drawing.Color]::FromArgb(50, 50, 50)
            $btn_fg = [System.Drawing.Color]::FromArgb(190, 190, 190); $btn_bord = [System.Drawing.Color]::FromArgb(90, 90, 90)
            $btn_hov = [System.Drawing.Color]::FromArgb(64, 64, 64) 
            $txt_bg = [System.Drawing.Color]::FromArgb(30, 30, 30); $txt_fg = [System.Drawing.Color]::FromArgb(220, 220, 220) }
        2 { $bgTop = [System.Drawing.Color]::FromArgb(232, 232, 232); $bgBot = [System.Drawing.Color]::FromArgb(210, 210, 210)
            $borderC = [System.Drawing.Color]::FromArgb(120, 140, 140, 140); $sepC = [System.Drawing.Color]::FromArgb(80, 140, 140, 140)
            $titleC = [System.Drawing.Color]::FromArgb(220, 50, 50, 50); $btn_bg = [System.Drawing.Color]::FromArgb(210, 210, 210)
            $btn_fg = [System.Drawing.Color]::FromArgb(40, 40, 40); $btn_bord = [System.Drawing.Color]::FromArgb(130, 130, 130)
            $btn_hov = [System.Drawing.Color]::FromArgb(192, 192, 192)
            $txt_bg = [System.Drawing.Color]::FromArgb(250, 250, 250); $txt_fg = [System.Drawing.Color]::FromArgb(30, 30, 30) }
        3 { $bgTop = [System.Drawing.Color]::FromArgb(30, 45, 60); $bgBot = [System.Drawing.Color]::FromArgb(10, 20, 30)
            $borderC = [System.Drawing.Color]::FromArgb(80, 130, 180); $sepC = [System.Drawing.Color]::FromArgb(50, 90, 130)
            $titleC = [System.Drawing.Color]::FromArgb(200, 230, 255); $btn_bg = [System.Drawing.Color]::FromArgb(35, 50, 70)
            $btn_fg = [System.Drawing.Color]::FromArgb(180, 220, 255); $btn_bord = [System.Drawing.Color]::FromArgb(80, 130, 180)
            $btn_hov = [System.Drawing.Color]::FromArgb(50, 75, 105)
            $txt_bg = [System.Drawing.Color]::FromArgb(20, 30, 45); $txt_fg = [System.Drawing.Color]::FromArgb(200, 230, 255) }
        default { $bgTop = [System.Drawing.Color]::FromArgb(10, 18, 34); $bgBot = [System.Drawing.Color]::FromArgb(4, 9, 18)
            $borderC = [System.Drawing.Color]::FromArgb(70, 80, 200, 150); $sepC = [System.Drawing.Color]::FromArgb(35, 80, 200, 150)
            $titleC = [System.Drawing.Color]::FromArgb(200, 180, 220, 200); $btn_bg = [System.Drawing.Color]::FromArgb(8, 20, 14)
            $btn_fg = [System.Drawing.Color]::FromArgb(95, 215, 155); $btn_bord = [System.Drawing.Color]::FromArgb(70, 200, 140)
            $btn_hov = [System.Drawing.Color]::FromArgb(14, 40, 26)
            $txt_bg = [System.Drawing.Color]::FromArgb(10, 22, 38); $txt_fg = [System.Drawing.Color]::FromArgb(180, 255, 200) }
    }

    $sw = New-Object System.Windows.Forms.Form
    $sw.Text = ""; $sw.Size = New-Object System.Drawing.Size(300, 250); $sw.StartPosition = 'CenterParent'
    $sw.FormBorderStyle = 'None'; $sw.MaximizeBox = $false; $sw.MinimizeBox = $false
    $sw.ShowInTaskbar = $false; $sw.BackColor = $bgBot

    $bgTopARGB = $bgTop.ToArgb(); $bgBotARGB = $bgBot.ToArgb(); $borderARGB = $borderC.ToArgb()
    $sepARGB = $sepC.ToArgb(); $titleARGB = $titleC.ToArgb()

    $sw.Add_Paint({
        param($s, $e)
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $W = $s.ClientSize.Width; $H = $s.ClientSize.Height
        $cTop = [System.Drawing.Color]::FromArgb($bgTopARGB); $cBot = [System.Drawing.Color]::FromArgb($bgBotARGB)
        $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush([System.Drawing.Point]::new(0,0), [System.Drawing.Point]::new(0,$H), $cTop, $cBot)
        $g.FillRectangle($grad, 0, 0, $W, $H); $grad.Dispose()
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($borderARGB), 1)
        $g.DrawRectangle($pen, 0, 0, ($W-1), ($H-1)); $pen.Dispose()
        $sepPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($sepARGB), 1)
        $g.DrawLine($sepPen, 1, 38, ($W-2), 38); $sepPen.Dispose()
        $fnt = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $br  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($titleARGB))
        $g.DrawString("Ustawienia", $fnt, $br, 12, 12); $fnt.Dispose(); $br.Dispose()
    }.GetNewClosure())

    $sw.Add_MouseDown({
        param($s, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $e.Y -lt 38) {
            [WinAPI]::ReleaseCapture() | Out-Null
            [WinAPI]::SendMessage($s.Handle, [WinAPI]::WM_NCLBUTTONDOWN, [IntPtr][WinAPI]::HTCAPTION, [IntPtr]::Zero) | Out-Null
        }
    })

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "✕"; $btnClose.Size = New-Object System.Drawing.Size(28, 28)
    $btnClose.Location = New-Object System.Drawing.Point(($sw.ClientSize.Width - 32), 5)
    $btnClose.FlatStyle = 'Flat'; $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(70, 200, 60, 60)
    $btnClose.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(120, 180, 40, 40)
    $btnClose.BackColor = [System.Drawing.Color]::Transparent; $btnClose.ForeColor = $titleC
    $btnClose.Font = New-Object System.Drawing.Font('Segoe UI', 9); $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $sw.Controls.Add($btnClose); $btnClose.Add_Click({ $sw.Close() })

    $mkSwBtn = {
        param([string]$txt, [int]$yPos)
        $b = New-Object System.Windows.Forms.Button; $b.Text = $txt
        $b.Location = New-Object System.Drawing.Point(15, $yPos); $b.Size = New-Object System.Drawing.Size(268, 36)
        $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderColor = $btn_bord; $b.FlatAppearance.BorderSize = 1
        $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(30, 180, 180, 180)
        $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(60, 180, 180, 180)
        $b.BackColor = [System.Drawing.Color]::Transparent; $b.ForeColor = $btn_fg
        $b.Font = New-Object System.Drawing.Font('Segoe UI', 9); $b.Cursor = [System.Windows.Forms.Cursors]::Hand
        return $b
    }

    $btnT = & $mkSwBtn $script:themeLabels[$script:currentTheme] 50
    $sw.Controls.Add($btnT)
    $btnT.Add_Click({
        $script:currentTheme = ($script:currentTheme + 1) % 4
        $btnT.Text = $script:themeLabels[$script:currentTheme]; Apply-Theme -theme $script:currentTheme
    })

    $btnLC = & $mkSwBtn "Wczytaj config" 96
    $sw.Controls.Add($btnLC)
    $btnLC.Add_Click({
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Title = "Wybierz plik konfiguracyjny Aurora Deck"
        $ofd.Filter = "Pliki JSON (*.json)|*.json|Wszystkie pliki (*.*)|*.*"
        $ofd.InitialDirectory = $script:scriptDir
        if ($ofd.ShowDialog($sw) -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:dataFile = $ofd.FileName
            $newSize = (Get-Settings).TileSize
            if ($newSize -ge 70 -and $newSize -le 180) { $script:tileSize = $newSize; $sizeSlider.Value = $newSize; $lblSizeVal.Text = "$newSize px" }
            Rebuild-Tiles; Rebuild-FolderPanel; Update-Weather
        }
        $ofd.Dispose()
    })

    $lblCity = New-Object System.Windows.Forms.Label
    $lblCity.Text = "Miasto (Pogoda):"; $lblCity.Location = New-Object System.Drawing.Point(12, 145); $lblCity.AutoSize = $true
    $lblCity.BackColor = 'Transparent'; $lblCity.ForeColor = $titleC; $lblCity.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $sw.Controls.Add($lblCity)

    $txtCity = New-Object System.Windows.Forms.TextBox
    $txtCity.Location = New-Object System.Drawing.Point(15, 165); $txtCity.Size = New-Object System.Drawing.Size(268, 24)
    $txtCity.BackColor = $txt_bg; $txtCity.ForeColor = $txt_fg; $txtCity.BorderStyle = 'FixedSingle'
    $txtCity.Font = New-Object System.Drawing.Font('Segoe UI', 10); $txtCity.Text = (Get-Settings).City
    $sw.Controls.Add($txtCity)

    $btnSaveCity = & $mkSwBtn "Zapisz i Odśwież Pogodę" 200
    $sw.Controls.Add($btnSaveCity)
    $btnSaveCity.Add_Click({
        Save-Settings -tileSize $script:tileSize -theme $script:currentTheme -city $txtCity.Text
        Update-Weather
        $sw.Close()
    })

    $sw.ShowDialog($form) | Out-Null; $sw.Dispose()
}

$script:btnSettings = New-Object System.Windows.Forms.Button
$script:btnSettings.Text = "Ustawienia"; $script:btnSettings.Size = New-Object System.Drawing.Size(130, 28)
$script:btnSettings.Location = New-Object System.Drawing.Point((($bottomPanel.Width - 130) / 2), 13)
$script:btnSettings.Anchor = 'Bottom'; $script:btnSettings.FlatStyle = 'Flat'
$script:btnSettings.FlatAppearance.BorderSize = 0
$script:btnSettings.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(30, 180, 180, 180)
$script:btnSettings.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(60, 180, 180, 180)
$script:btnSettings.BackColor = [System.Drawing.Color]::Transparent; $script:btnSettings.ForeColor = [System.Drawing.Color]::FromArgb(95, 215, 155)
$script:btnSettings.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
$script:btnSettings.Cursor = [System.Windows.Forms.Cursors]::Hand; $script:btnSettings.Visible = $false
$bottomPanel.Controls.Add($script:btnSettings); $script:btnSettings.Add_Click({ Show-SettingsWindow })

$script:searchBox.Add_GotFocus({
    if ($script:searchPlaceholder) {
        $script:searchPlaceholder = $false; $script:searchBox.Text = ''
        $script:searchBox.ForeColor = [System.Drawing.Color]::FromArgb(140, 255, 190)
    }
})
$script:searchBox.Add_LostFocus({
    if ($script:searchBox.Text.Trim() -eq '') {
        $script:searchPlaceholder = $true; $script:searchBox.ForeColor = [System.Drawing.Color]::FromArgb(65, 110, 90)
        $script:searchBox.Text = '🔍 Szukaj aplikacji...'
    }
})
$script:searchBox.add_TextChanged({ Invoke-TileLayout })
$lblSizeVal.ForeColor = [System.Drawing.Color]::FromArgb(110, 100, 255, 180)
$lblSizeVal.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
$bottomPanel.Controls.Add($lblSizeVal); $lblSizeVal.Visible = $false

$pinBtn.add_PinChanged({ $form.TopMost = $pinBtn.IsPinned })
$lockBtn.add_LockChanged({
    if (-not $lockBtn.IsLocked) {
        $script:isUnlocked = $true; $script:isEditMode = $true; Set-EditMode -enabled $true; $script:btnSettings.Visible = $true
    } else {
        $script:isEditMode = $false; $script:isUnlocked = $false; Set-EditMode -enabled $false; $script:btnSettings.Visible = $false
    }
})
$sizeSlider.add_ValueChanged({ $v = $sizeSlider.Value; $lblSizeVal.Text = "$v px"; Set-TileSize -size $v; Save-Settings -tileSize $v })
$form.Add_DragEnter({ Handle-DragEnter -e $_ }); $form.Add_DragDrop({ Handle-DragDrop -e $_ })
$form.Add_Resize({ $script:btnSettings.Location = New-Object System.Drawing.Point((($bottomPanel.Width - 130) / 2), 13); Invoke-TileLayout })

$savedApps = Get-AppConfig
foreach ($entry in $savedApps) { if ($entry.Path) { $tile = New-TileControl $entry; $form.Controls.Add($tile) } }

Rebuild-FolderPanel; Invoke-TileLayout
$script:sidebarPanel.BringToFront(); $script:sidebarIndicator.BringToFront()
Apply-Theme -theme $script:currentTheme

[System.Windows.Forms.Application]::Run($form)

ale jaja