using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

public sealed class ETLMonitor : Form {
    private readonly string run,folder;
    private readonly JavaScriptSerializer json=new JavaScriptSerializer();
    private readonly Dictionary<string,Label> stages=new Dictionary<string,Label>();
    private readonly Label headline=new Label(),taskLabel=new Label(),meter=new Label(),heartbeat=new Label();
    private readonly TextBox error=new TextBox(),child=new TextBox();
    private readonly ListView events=new ListView();
    private readonly Timer timer=new Timer();
    private int consumed;
    private static string S(Dictionary<string,object> d,string k){object v;return d.TryGetValue(k,out v)&&v!=null?v.ToString():"";}
    private static long N(Dictionary<string,object> d,string k){long n;return Int64.TryParse(S(d,k),out n)?n:0;}
    private static string ReadShared(string path){using(var f=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete))using(var r=new StreamReader(f,Encoding.UTF8))return r.ReadToEnd();}
    public ETLMonitor(string id,string logRoot) {
        run=id;folder=Path.Combine(logRoot,id);Text="NYCTaxi ETL Monitor — "+id;
        ClientSize=new Size(1210,850);MinimumSize=new Size(1100,820);StartPosition=FormStartPosition.CenterScreen;AutoScaleMode=AutoScaleMode.Dpi;
        BackColor=Color.FromArgb(242,246,249);Font=new Font("Segoe UI",10);ForeColor=Color.FromArgb(25,48,68);
        Controls.Add(new Label{Text="NYC TAXI  /  ETL MONITOR",Location=new Point(24,16),Size=new Size(1000,38),Font=new Font("Segoe UI",22,FontStyle.Bold)});
        Controls.Add(new Label{Text="RunId: "+id,Location=new Point(26,61),Size=new Size(930,24),Font=new Font("Consolas",10)});
        var copy=new Button{Text="Copy RunId",Location=new Point(1040,57),Size=new Size(140,30)};copy.Click+=delegate{Clipboard.SetText(run);};Controls.Add(copy);
        headline.Location=new Point(24,100);headline.Size=new Size(1155,42);headline.Padding=new Padding(12,8,8,4);headline.BackColor=Color.FromArgb(226,236,244);headline.Text="Đang chờ Master bắt đầu…";Controls.Add(headline);
        string[] names={"Extract","Transform","Dwh","Aggregates","Ssas"};
        for(int i=0;i<names.Length;i++){var l=new Label{Text=(i+1)+". "+names[i]+"\nChưa chạy",Location=new Point(24+i*234,156),Size=new Size(219,57),Padding=new Padding(8),BackColor=Color.FromArgb(225,231,237)};stages[names[i]]=l;Controls.Add(l);}
        taskLabel.Location=new Point(26,226);taskLabel.Size=new Size(1150,28);taskLabel.Font=new Font("Segoe UI",12,FontStyle.Bold);Controls.Add(taskLabel);
        meter.Location=new Point(26,260);meter.Size=new Size(740,25);Controls.Add(meter);
        heartbeat.Location=new Point(770,260);heartbeat.Size=new Size(408,25);heartbeat.TextAlign=ContentAlignment.TopRight;Controls.Add(heartbeat);
        error.Location=new Point(24,296);error.Size=new Size(1155,82);error.Multiline=true;error.ReadOnly=true;error.ScrollBars=ScrollBars.Vertical;error.BackColor=Color.White;error.ForeColor=Color.Firebrick;error.Text="";Controls.Add(error);
        events.Location=new Point(24,390);events.Size=new Size(1155,247);events.View=View.Details;events.FullRowSelect=true;events.GridLines=true;
        events.Columns.Add("Giờ",80);events.Columns.Add("Stage",95);events.Columns.Add("Trạng thái",100);events.Columns.Add("Task",270);events.Columns.Add("Chi tiết",565);Controls.Add(events);
        Controls.Add(new Label{Text="Output",Location=new Point(24,647),Size=new Size(1100,25)});
        child.Location=new Point(24,675);child.Size=new Size(1155,102);child.Multiline=true;child.ReadOnly=true;child.ScrollBars=ScrollBars.Vertical;child.Font=new Font("Consolas",9);child.BackColor=Color.White;Controls.Add(child);
        var logs=new Button{Text="Mở thư mục log",Location=new Point(24,794),Size=new Size(170,34)};logs.Click+=delegate{if(Directory.Exists(folder))Process.Start(new ProcessStartInfo(folder){UseShellExecute=true});};Controls.Add(logs);
        var errCopy=new Button{Text="Copy lỗi / resume",Location=new Point(208,794),Size=new Size(250,34)};errCopy.Click+=delegate{Clipboard.SetText(error.Text+"\nRunId="+run+"\nLogs="+folder);};Controls.Add(errCopy);
        Controls.Add(new Label{Text="",Location=new Point(478,800),Size=new Size(710,35),Font=new Font("Segoe UI",9)});
        timer.Interval=1000;timer.Tick+=delegate{RefreshLog();};timer.Start();Shown+=delegate{RefreshLog();};
    }
    private void Stage(string name,string state){
        Label label;if(!stages.TryGetValue(name,out label))return;
        string text=state;Color color=Color.FromArgb(225,231,237);
        if(state=="RUNNING"){text="Đang chạy";color=Color.FromArgb(216,234,251);}
        if(state=="SUCCEEDED"){text="Hoàn tất";color=Color.FromArgb(212,239,222);}
        if(state=="FAILED"){text="Thất bại";color=Color.MistyRose;}
        if(state=="RETRYING"){text="Đang thử lại";color=Color.FromArgb(255,239,203);}
        if(state=="SKIPPED"){text="Checkpoint đã hoàn tất";color=Color.FromArgb(212,239,222);}
        if(state=="INVALIDATED"){text="Cần chạy lại";}
        label.Text=name+"\n"+text;label.BackColor=color;
    }
    private void RefreshLog(){
        try{
            string journal=Path.Combine(folder,"events.jsonl");
            if(File.Exists(journal)){
                var lines=ReadShared(journal).Split(new[]{'\n'},StringSplitOptions.RemoveEmptyEntries);
                if(lines.Length<consumed){consumed=0;events.Items.Clear();}
                for(;consumed<lines.Length;consumed++){
                    Dictionary<string,object> e;try{e=(Dictionary<string,object>)json.DeserializeObject(lines[consumed]);}catch{break;}
                    string state=S(e,"Status"),stage=S(e,"Stage"),task=S(e,"Task");
                    if(task=="StageComplete"||state=="SKIPPED"||state=="RETRYING"||state=="INVALIDATED"||state=="FAILED")Stage(stage,state);
                    else if(state=="RUNNING")Stage(stage,"RUNNING");
                    DateTimeOffset utc;string time=DateTimeOffset.TryParse(S(e,"Utc"),out utc)?utc.ToOffset(TimeSpan.FromHours(7)).ToString("HH:mm:ss"):"";
                    string detail=S(e,"Detail").Replace("\r"," ").Replace("\n"," ");if(detail.Length>900)detail=detail.Substring(0,900);
                    var row=new ListViewItem(new[]{time,stage,state,task,detail});if(state=="FAILED")row.ForeColor=Color.Firebrick;events.Items.Add(row);
                }
                if(events.Items.Count>0)events.Items[events.Items.Count-1].EnsureVisible();
            }
            string status=Path.Combine(folder,"status.json");if(!File.Exists(status))return;
            var data=(Dictionary<string,object>)json.DeserializeObject(ReadShared(status));string phase=S(data,"Stage"),stateNow=S(data,"Status"),taskNow=S(data,"Task");
            headline.Text=phase+" / "+stateNow+" — "+S(data,"Message");headline.BackColor=stateNow=="FAILED"?Color.MistyRose:stateNow=="RETRYING"?Color.FromArgb(255,239,203):Color.FromArgb(226,236,244);
            if(taskNow=="MasterComplete"){headline.Text="HOÀN TẤT ";headline.BackColor=Color.FromArgb(212,239,222);}
            taskLabel.Text="Task hiện tại: "+taskNow;
            DateTimeOffset started,beat;bool hasBeat=DateTimeOffset.TryParse(S(data,"HeartbeatUtc"),out beat);DateTimeOffset end=stateNow=="RUNNING"||!hasBeat?DateTimeOffset.UtcNow:beat;double seconds=DateTimeOffset.TryParse(S(data,"TaskStartedUtc"),out started)?Math.Max(0,(end-started).TotalSeconds):0;
            long count=N(data,"Rows"),total=N(data,"TotalRows");
            meter.Text=total>0?String.Format("Đã ghi wrk: {0:N0} / {1:N0} dòng ({2:0.0}%). Chưa tính commit staging.",count,total,100.0*count/total):"Thời gian task: "+TimeSpan.FromSeconds(seconds).ToString(@"hh\:mm\:ss");
            double age=DateTimeOffset.TryParse(S(data,"HeartbeatUtc"),out beat)?(DateTimeOffset.UtcNow-beat).TotalSeconds:0;
            heartbeat.Text=stateNow=="RUNNING"&&age>20?"Chưa có heartbeat "+(int)age+"s; kiểm tra trước khi restart":"Log cuối: "+(hasBeat?beat.ToLocalTime().ToString("HH:mm:ss"):"chưa có");
            if(stateNow=="FAILED"||stateNow=="RETRYING"){
                error.Text=S(data,"Message")+"\r\n\r\nResume: pResumeRunId="+run+"; pStartStage="+(stages.ContainsKey(phase)?phase:"Extract")+". Giữ nguyên cấu hình lần cũ.\r\nLog: "+folder;
                if(S(data,"Message").Contains("Unfinished run exists")){
                    var target=System.Text.RegularExpressions.Regex.Match(S(data,"Message"),@"ResumeRunId=([0-9a-fA-F-]{36}); ResumeFrom=(Extract|Transform|Dwh|Aggregates|Ssas)");
                    error.Text=S(data,"Message")+"\r\n\r\n"+(target.Success?"Resume: pResumeRunId="+target.Groups[1].Value+"; pStartStage="+target.Groups[2].Value:"Resume: cần xác định RunId RUNNING trong etl.PipelineRun trước khi chạy tiếp.")+"\r\nLog: "+folder;
                }
            }else if(taskNow=="MasterComplete")error.Text="Không có lỗi chưa xử lý. RunId="+run;
            string label=S(data,"ChildLabel");
            if(!String.IsNullOrEmpty(label)&&Path.GetFileName(label)==label){
                var files=new[]{Path.Combine(folder,label+".stdout.log"),Path.Combine(folder,label+".stderr.log")};var tail=new List<string>();
                foreach(string file in files){if(File.Exists(file)){tail.Add(Path.GetFileName(file));tail.AddRange(ReadShared(file).Split(new[]{'\n'},StringSplitOptions.RemoveEmptyEntries).Reverse().Take(7).Reverse());}}
                child.Text=String.Join(Environment.NewLine,tail);
            }
        }catch(IOException){}catch(ArgumentException){}catch(Exception e){heartbeat.Text="Đang chờ bản log hoàn chỉnh: "+e.Message;}
    }
    [STAThread]public static void Main(string[] args){
        string id=null,root=null;for(int i=0;i+1<args.Length;i+=2){if(args[i]=="--run-id")id=args[i+1];if(args[i]=="--log-root")root=args[i+1];}
        if(args.Length==0){
            root=Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"..","logs"));
            if(Directory.Exists(root)){
                var latest=Directory.GetDirectories(root).Where(p=>File.Exists(Path.Combine(p,"status.json"))).OrderByDescending(p=>File.GetLastWriteTimeUtc(Path.Combine(p,"status.json"))).FirstOrDefault();
                if(latest!=null)id=Path.GetFileName(latest);
            }
        }
        Guid parsed;if(!Guid.TryParse(id,out parsed)||String.IsNullOrEmpty(root)){MessageBox.Show("Cần --run-id GUID và --log-root thư mục log.");return;}
        bool first;using(var mutex=new System.Threading.Mutex(true,"Local\\NYCTaxiETLMonitor_"+parsed.ToString("N"),out first)){
            if(!first)return;Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new ETLMonitor(parsed.ToString(),Path.GetFullPath(root)));
        }
    }
}
