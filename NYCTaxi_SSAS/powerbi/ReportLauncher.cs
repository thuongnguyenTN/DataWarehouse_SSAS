using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

public sealed class ReportLauncher : Form {
    private readonly string root = AppDomain.CurrentDomain.BaseDirectory;
    private readonly Dictionary<string,Label> states = new Dictionary<string,Label>();
    private readonly Color ink = Color.FromArgb(25,48,68);
    private readonly Label banner = new Label();
    private readonly Label checkedAt = new Label();
    private readonly Button refresh = new Button();
    private readonly JavaScriptSerializer json = new JavaScriptSerializer();
    private bool checking;
    private static string Read(Dictionary<string,object> d,string key) { object v;return d.TryGetValue(key,out v)&&v!=null?v.ToString():""; }
    private static bool Flag(Dictionary<string,object> d,string key) { object v;return d.TryGetValue(key,out v)&&v is bool&&(bool)v; }
    public ReportLauncher() {
        Text="NYC Taxi Analytics — Báo cáo Power BI Live";
        StartPosition=FormStartPosition.CenterScreen;
        ClientSize=new Size(1080,810); MinimumSize=new Size(1000,800);
        Font=new Font("Segoe UI",10); BackColor=Color.FromArgb(242,246,249); ForeColor=ink;
        AutoScaleMode=AutoScaleMode.Dpi;
        var title=new Label{Text="NYC TAXI  /  ANALYTICS",Location=new Point(30,22),Size=new Size(1000,42),Font=new Font("Segoe UI",25,FontStyle.Bold),ForeColor=ink};Controls.Add(title);
        Controls.Add(new Label{Text="Một điểm mở báo cáo · 6 cube nghiệp vụ · SSAS Live Connection",Location=new Point(32,70),Size=new Size(1000,28)});
        banner.Location=new Point(30,110);banner.Size=new Size(1020,66);banner.Padding=new Padding(14,10,10,8);banner.BackColor=Color.FromArgb(227,236,244);banner.Text="Đang kiểm tra nguồn SSAS…";Controls.Add(banner);
        Controls.Add(new Label{Text=@"THUONGNGUYEN\MSSQLSV  /  NYCTaxi_SSAS",Location=new Point(32,186),Size=new Size(700,24),Font=new Font("Segoe UI",9),ForeColor=Color.FromArgb(82,104,122)});
        var data=(object[])json.DeserializeObject(File.ReadAllText(Path.Combine(root,"report-index.json"),Encoding.UTF8));
        string[] names={"Taxi Yellow / Green","Xe công nghệ HVFHV","FHV truyền thống","Tài chính theo ngày","Lưu lượng khu vực","Hiệu suất Base"};
        string[] desc={"Nhu cầu · Giờ cao điểm · Thanh toán · Tiền tip","Thời gian chờ · Nhà cung cấp · Phí và tiền tài xế","Số chuyến · Thời lượng · Base điều phối","Tiền khách trả · Tip · Thuế và phí","Lượt đón / trả · Quận và zone · Giờ cao điểm","Số chuyến · Thời gian chờ · Yêu cầu đi chung"};
        Color[] accents={Color.DarkGoldenrod,Color.Teal,Color.SlateBlue,Color.SeaGreen,Color.SteelBlue,Color.Sienna};
        for(int i=0;i<data.Length;i++) {
            var item=(Dictionary<string,object>)data[i]; string cube=Read(item,"cube");string path=Read(item,"path");
            var card=new Panel{Location=new Point(30+(i%2)*520,220+(i/2)*155),Size=new Size(500,141),BackColor=Color.White,BorderStyle=BorderStyle.FixedSingle};
            card.Controls.Add(new Panel{Dock=DockStyle.Left,Width=5,BackColor=accents[i%accents.Length]});
            card.Controls.Add(new Label{Text=names[i],Location=new Point(18,12),Size=new Size(465,30),Font=new Font("Segoe UI",15,FontStyle.Bold)});
            card.Controls.Add(new Label{Text=desc[i],Location=new Point(19,47),Size=new Size(465,24),Font=new Font("Segoe UI",9)});
            var status=new Label{Text="Đang kiểm tra…",Location=new Point(19,87),Size=new Size(276,38),Font=new Font("Segoe UI",9),ForeColor=Color.DimGray};card.Controls.Add(status);states[cube]=status;
            var open=new Button{Text="Mở báo cáo Live",Location=new Point(315,86),Size=new Size(166,35),BackColor=accents[i%accents.Length],ForeColor=Color.White,FlatStyle=FlatStyle.Flat};
            open.FlatAppearance.BorderSize=0;open.Click+=delegate{OpenReport(path);};card.Controls.Add(open);Controls.Add(card);
        }
        refresh.Text="Kiểm tra kết nối";refresh.Location=new Point(30,704);refresh.Size=new Size(185,38);refresh.Click+=async delegate{await CheckHealth();};Controls.Add(refresh);
        var folder=new Button{Text="Thư mục báo cáo",Location=new Point(230,704),Size=new Size(185,38)};folder.Click+=delegate{Process.Start(new ProcessStartInfo(Path.Combine(root,"reports")){UseShellExecute=true});};Controls.Add(folder);
        var help=new Button{Text="Hướng dẫn sử dụng",Location=new Point(430,704),Size=new Size(185,38)};help.Click+=delegate{Process.Start(new ProcessStartInfo(Path.Combine(root,"START_HERE.txt")){UseShellExecute=true});};Controls.Add(help);
        checkedAt.Location=new Point(635,710);checkedAt.Size=new Size(415,42);checkedAt.Font=new Font("Segoe UI",9);checkedAt.TextAlign=ContentAlignment.TopRight;Controls.Add(checkedAt);
        Controls.Add(new Label{Text="Mỗi báo cáo mở trong một cửa sổ Power BI riêng. Menu này không chạy ETL hoặc process cube.",Location=new Point(30,763),Size=new Size(1020,26),Font=new Font("Segoe UI",9),ForeColor=Color.FromArgb(82,104,122)});
        Shown+=async delegate{await CheckHealth();};
    }
    private void OpenReport(string relative) {
        try {
            string cube=Path.GetFileNameWithoutExtension(relative);Label sourceState;
            if(checking||!states.TryGetValue(cube,out sourceState)||!sourceState.Text.StartsWith("Sẵn sàng",StringComparison.Ordinal)) {
                string detail=states.TryGetValue(cube,out sourceState)?sourceState.Text:"Chưa kiểm tra nguồn";
                MessageBox.Show(this,"Nguồn chưa sẵn sàng: "+detail+".\n\nSau lần clear dữ liệu, bạn cần tự chạy PKG_00_Master đến EPT_05_Ssas thành công. Sau đó bấm Kiểm tra kết nối và mở báo cáo lại.\n\nMenu không tự nạp dữ liệu hoặc process SSAS.","Báo cáo Live đang chờ nguồn",MessageBoxButtons.OK,MessageBoxIcon.Information);
                return;
            }
            string path=Path.GetFullPath(Path.Combine(root,relative));string approved=Path.Combine(root,"reports")+Path.DirectorySeparatorChar;
            if(!path.StartsWith(approved,StringComparison.OrdinalIgnoreCase)||!path.EndsWith(".pbip",StringComparison.OrdinalIgnoreCase)||!File.Exists(path))throw new IOException("Không tìm thấy project Power BI hợp lệ: "+path);
            try {Process.Start(new ProcessStartInfo(path){UseShellExecute=true});}
            catch(System.ComponentModel.Win32Exception){
                string desktopFile=Path.Combine(root,"desktop-path.txt");
                if(!File.Exists(desktopFile))throw;
                string exe=File.ReadAllText(desktopFile,Encoding.UTF8).Trim();
                if(!File.Exists(exe)||!String.Equals(Path.GetFileName(exe),"PBIDesktop.exe",StringComparison.OrdinalIgnoreCase))throw new IOException("Chưa tìm thấy Power BI Desktop. Mở file .pbip bằng Power BI Desktop.");
                Process.Start(new ProcessStartInfo(exe,"\""+path+"\""){UseShellExecute=true});
            }
        }catch(Exception e){MessageBox.Show(this,e.Message,"Không mở được báo cáo",MessageBoxButtons.OK,MessageBoxIcon.Warning);}
    }
    private async Task CheckHealth() {
        if(checking)return;checking=true;refresh.Enabled=false;banner.Text="Đang kiểm tra kết nối và trạng thái các cube…";
        try {
            string output=await Task.Run(delegate {
                var psi=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\WindowsPowerShell\v1.0\powershell.exe"),"-NoProfile -ExecutionPolicy Bypass -File \""+Path.Combine(root,"Get-ReportHealth.ps1")+"\"") {UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true,StandardOutputEncoding=Encoding.UTF8,StandardErrorEncoding=Encoding.UTF8};
                using(var p=Process.Start(psi)){
                    var stdout=p.StandardOutput.ReadToEndAsync();var stderr=p.StandardError.ReadToEndAsync();
                    if(!p.WaitForExit(45000)){try{p.Kill();}catch{}throw new TimeoutException("Kiểm tra SSAS quá 45 giây. Kiểm tra SQL Server Analysis Services và thử lại.");}
                    Task.WaitAll(stdout,stderr);if(p.ExitCode!=0)throw new IOException(stderr.Result);return stdout.Result;
                }
            });
            var health=(Dictionary<string,object>)json.DeserializeObject(output);
            if(!Flag(health,"ServerReachable")||Read(health,"Error")!="")throw new IOException(Read(health,"Error"));
            int ready=0,pending=0,bad=0;
            foreach(object value in (object[])health["Reports"]){
                var item=(Dictionary<string,object>)value;string cube=Read(item,"Cube");Label label;if(!states.TryGetValue(cube,out label))continue;
                if(!Flag(item,"ConfigValid")||!Flag(item,"ReportExists")){label.Text="Lỗi cấu hình / file báo cáo";label.ForeColor=Color.Firebrick;bad++;}
                else if(Read(item,"State")!="Processed"){label.Text="Chờ process SSAS · Live đã cấu hình";label.ForeColor=Color.DarkGoldenrod;pending++;}
                else if(!Flag(item,"ProbePassed")){label.Text="Cube đã process · lỗi truy vấn Live";label.ForeColor=Color.Firebrick;bad++;}
                else{label.Text="Sẵn sàng · Live Connection";label.ForeColor=Color.SeaGreen;ready++;}
            }
            if(bad>0){banner.BackColor=Color.MistyRose;banner.Text=bad+" báo cáo cần kiểm tra cấu hình hoặc truy vấn. Xem Get-ReportHealth.ps1 để lấy thông báo chi tiết.";}
            else if(pending>0){banner.BackColor=Color.FromArgb(255,242,209);banner.Text="Kết nối server thành công. "+pending+" cube chưa process.\nSau khi bạn chạy Master đến bước SSAS thành công, bấm Kiểm tra kết nối rồi Refresh trong Power BI.";}
            else{banner.BackColor=Color.FromArgb(218,241,230);banner.Text="Nguồn sẵn sàng — "+ready+" / 6 báo cáo có thể truy vấn Live. Chọn nghiệp vụ bên dưới để mở Power BI.";}
            checkedAt.Text="Kiểm tra: "+DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss");
        }catch(Exception e){banner.BackColor=Color.MistyRose;banner.Text="Không kiểm tra được SSAS: "+e.Message;foreach(var label in states.Values){label.Text="Chưa xác định · kiểm tra nguồn";label.ForeColor=Color.Firebrick;}}
        finally{checking=false;refresh.Enabled=true;}
    }
    [STAThread] public static void Main(string[] args) {
        Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
        try{Application.Run(new ReportLauncher());}catch(Exception e){MessageBox.Show(e.Message,"NYC Taxi Analytics",MessageBoxButtons.OK,MessageBoxIcon.Error);}
    }
}
