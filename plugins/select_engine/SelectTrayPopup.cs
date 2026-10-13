using System;
using System.Collections;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

internal static class SelectTrayPopup {
  private static readonly Stream Input = Console.OpenStandardInput();
  private static readonly StreamWriter Output = new StreamWriter(Console.OpenStandardOutput(), new UTF8Encoding(false)) { AutoFlush = true };
  private static string ReadInputLine() {
    using (var bytes = new MemoryStream()) {
      int value;
      while ((value = Input.ReadByte()) != -1) {
        if (value == 10) return Encoding.UTF8.GetString(bytes.ToArray()).TrimEnd('\r');
        bytes.WriteByte((byte)value);
      }
      return bytes.Length == 0 ? null : Encoding.UTF8.GetString(bytes.ToArray());
    }
  }
  [DllImport("user32.dll")] private static extern bool SetProcessDPIAware();
  [STAThread] private static void Main(string[] args) {
    SetProcessDPIAware();


    Application.EnableVisualStyles();
    var first = ReadInputLine();
    if (String.IsNullOrWhiteSpace(first)) return;
    using (var form = new MenuWindow(first)) {
      if (args.Length == 2 && (args[0] == "--render" || args[0] == "--render-updated")) {
        if (args[0] == "--render-updated") {
          var original = form.Controls[0];
          form.Apply(ReadInputLine());
          if (!Object.ReferenceEquals(original, form.Controls[0])) throw new InvalidOperationException("Button replaced during refresh");
          ((TileButton)form.Controls[0]).TestClick();
        }
        form.CreateControl();
        using (var bitmap = new Bitmap(form.Width, form.Height)) {
          form.DrawToBitmap(bitmap, form.ClientRectangle);
          foreach (Control child in form.Controls) child.DrawToBitmap(bitmap, child.Bounds);
          bitmap.Save(args[1]);
        }
        return;
      }
      bool streamTest = args.Length == 2 && args[0] == "--stream-test";
      if (streamTest) { form.Opacity = 0; form.TestMode = true; }
      var stateTimer = new System.Windows.Forms.Timer { Interval = 100 };
      string previous = first;
      stateTimer.Tick += delegate {
        if (args.Length != 2) return;
        try {
          string current = File.ReadAllText(args[1], Encoding.UTF8);
          if (current == previous) return;
          form.Apply(current);
          previous = current;
          if (streamTest) Output.WriteLine("STATE:" + form.Controls[0].AccessibleDescription);
        } catch (IOException) { } catch (ArgumentException) { }
      };
      form.Shown += delegate {
        if (streamTest) Output.WriteLine("READY");
        stateTimer.Start();
        var lifetime = new Thread(delegate() {
          try {
            while (ReadInputLine() != null) { }
            form.BeginInvoke(new Action(form.Close));
          } catch (InvalidOperationException) { } catch (IOException) { }
        });
        lifetime.IsBackground = true;
        lifetime.Start();
      };
      form.FormClosed += delegate { stateTimer.Stop(); stateTimer.Dispose(); };
      Application.Run(form);
    }
  }

  internal static GraphicsPath Shape(RectangleF r, float radius) {
    float d = Math.Min(radius, Math.Min(r.Width, r.Height) / 2);
    var p = new GraphicsPath();
    p.StartFigure();
    p.AddLine(r.Left + d, r.Top, r.Right - d, r.Top);
    p.AddBezier(r.Right-d,r.Top,r.Right,r.Top,r.Right,r.Top,r.Right,r.Top+d);
    p.AddLine(r.Right,r.Top+d,r.Right,r.Bottom-d);
    p.AddBezier(r.Right,r.Bottom-d,r.Right,r.Bottom,r.Right,r.Bottom,r.Right-d,r.Bottom);
    p.AddLine(r.Right-d,r.Bottom,r.Left+d,r.Bottom);
    p.AddBezier(r.Left+d,r.Bottom,r.Left,r.Bottom,r.Left,r.Bottom,r.Left,r.Bottom-d);
    p.AddLine(r.Left,r.Bottom-d,r.Left,r.Top+d);
    p.AddBezier(r.Left,r.Top+d,r.Left,r.Top,r.Left,r.Top,r.Left+d,r.Top);
    p.CloseFigure();
    return p;
  }

  private sealed class MenuWindow : Form {
    public bool TestMode;
    protected override bool ShowWithoutActivation { get { return TestMode; } }
    private Color border;
    private readonly float scale;
    private readonly ToolTip tips = new ToolTip();
    public MenuWindow(string data) {
      using (var g = Graphics.FromHwnd(IntPtr.Zero)) scale = g.DpiX / 96f;
      FormBorderStyle = FormBorderStyle.None;
      StartPosition = FormStartPosition.Manual;
      ShowInTaskbar = false;
      TopMost = true;
      DoubleBuffered = true;
      KeyPreview = true;
      Font = new Font("Segoe UI", 10f);
      Apply(data);
      var cursor = Cursor.Position;
      var area = Screen.FromPoint(cursor).WorkingArea;
      Location = new Point(Math.Max(area.Left, Math.Min(cursor.X-Width, area.Right-Width)),
        Math.Max(area.Top, Math.Min(cursor.Y-Height-6, area.Bottom-Height)));
      Deactivate += delegate { if (!TestMode) Close(); };
      KeyDown += delegate(object sender, KeyEventArgs e) { if (e.KeyCode == Keys.Escape) Close(); };
    }
    private int Px(int value) { return (int)Math.Round(value * scale); }
    private static Color ColorOf(IDictionary data, string key) {
      return ColorTranslator.FromHtml(Convert.ToString(data[key]));
    }
    public void Apply(string json) {
      var data = (IDictionary)new JavaScriptSerializer().DeserializeObject(json);
      var rows = new ArrayList();
      foreach (var row in (IEnumerable)data["rows"]) rows.Add(row);
      SuspendLayout();

      BackColor = ColorOf(data, "background");
      border = ColorOf(data, "border");
      ClientSize = new Size(Px(330), Px(24 + rows.Count * 48 - 6));
      using (var path = Shape(new RectangleF(0, 0, Width, Height), Px(16))) {
        var old = Region;
        Region = new Region(path);
        if (old != null) old.Dispose();
      }
      int y = Px(12);
      int nextIndex = 0;
      foreach (var row in rows) {
        var items = new ArrayList();
        foreach (var item in (IEnumerable)row) items.Add(item);
        int width = (Width - Px(24) - Px(6) * (items.Count-1)) / items.Count;
        for (int i=0; i<items.Count; i++) {
          var item = (IDictionary)items[i];
          bool selected = Convert.ToBoolean(item["selected"]);
          TileButton button;
          if (nextIndex < Controls.Count) {
            button = (TileButton)Controls[nextIndex];
          } else {
            button = new TileButton();
            button.Click += delegate(object sender, EventArgs e) {
              var source = (TileButton)sender;
              var action = (object[])source.Tag;
              Output.WriteLine(action[0]);
              Output.Flush();
              if ((bool)action[1]) Close();
            };
            Controls.Add(button);
          }
          button.Text = Convert.ToString(item["label"]);
          button.AccessibleName = button.Text;
          button.AccessibleDescription = selected ? "Selected" : "";
          button.Enabled = Convert.ToBoolean(item["enabled"]);
          button.ForeColor = ColorOf(data, selected ? "onAccent" : "foreground");
          button.Fill = ColorOf(data, selected ? "accent" : "surface");
          button.Edge = border;
          button.Bounds = new Rectangle(Px(12) + i*(width+Px(6)), y, width, Px(42));
          button.TabIndex = nextIndex++;
          button.Tag = new object[] { Convert.ToInt32(item["id"]), Convert.ToBoolean(item["close"]) };
          button.Invalidate();
          tips.SetToolTip(button, Convert.ToString(item["detail"]));
        }
        y += Px(48);
      }
      while (Controls.Count > nextIndex) {
        var extra = Controls[Controls.Count-1]; Controls.Remove(extra); extra.Dispose();
      }
      ResumeLayout();
      Invalidate(true);
    }
    protected override void OnPaint(PaintEventArgs e) {
      base.OnPaint(e);
      e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
      using (var p = Shape(new RectangleF(0.5f,0.5f,Width-1,Height-1),Px(16)))
      using (var pen = new Pen(border, 1)) e.Graphics.DrawPath(pen,p);
    }
    protected override void Dispose(bool disposing) {
      if (disposing) tips.Dispose();
      base.Dispose(disposing);
    }
  }
  private sealed class TileButton : Button {
    public Color Fill, Edge;
    private bool pressed, hovered;
    internal void TestClick() { OnClick(EventArgs.Empty); }
    protected override void OnMouseDown(MouseEventArgs e) { pressed = true; Invalidate(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { pressed = false; Invalidate(); base.OnMouseUp(e); }
    protected override void OnMouseEnter(EventArgs e) { hovered = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hovered = false; pressed = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnKeyDown(KeyEventArgs e) { if(e.KeyCode == Keys.Space) { pressed = true; Invalidate(); } base.OnKeyDown(e); }
    protected override void OnKeyUp(KeyEventArgs e) { pressed = false; Invalidate(); base.OnKeyUp(e); }
    private Color DisplayFill() {
      double factor = pressed ? 0.68 : hovered ? 0.88 : 1;
      return Color.FromArgb(Fill.A, (int)(Fill.R*factor), (int)(Fill.G*factor), (int)(Fill.B*factor));
    }
    public TileButton() {
      SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
      FlatStyle = FlatStyle.Flat;
      FlatAppearance.BorderSize = 0;
      Cursor = Cursors.Hand;
    }
    protected override void OnPaint(PaintEventArgs e) {
      e.Graphics.Clear(Parent.BackColor);
      e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
      using (var path = Shape(new RectangleF(1,1,Width-2,Height-2),12))
      using (var brush = new SolidBrush(DisplayFill()))
      using (var pen = new Pen(Edge,1)) {
        e.Graphics.FillPath(brush,path);
        e.Graphics.DrawPath(pen,path);
      }
      TextRenderer.DrawText(e.Graphics,Text,Font,ClientRectangle,
        Enabled ? ForeColor : SystemColors.GrayText,
        TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
    }
  }
}







