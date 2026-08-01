using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;

[assembly: AssemblyTitle("DeltaMap")]
[assembly: AssemblyProduct("DeltaMap 战术地图")]
[assembly: AssemblyDescription("轻量化三角洲全面战场地图编辑工具")]
[assembly: AssemblyCompany("JDI")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        try
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DeltaMap", "app");
            string version = assembly.ManifestModule.ModuleVersionId.ToString("N");
            string marker = Path.Combine(root, ".version");

            if (!File.Exists(marker) || File.ReadAllText(marker) != version)
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
                Directory.CreateDirectory(root);
                string package = Path.Combine(Path.GetTempPath(), "DeltaMap-" + version + ".zip");
                using (Stream input = assembly.GetManifestResourceStream("DeltaMap.package.zip"))
                using (FileStream output = File.Create(package)) input.CopyTo(output);
                ZipFile.ExtractToDirectory(package, root);
                File.Delete(package);
                File.WriteAllText(marker, version);
            }

            string index = Path.Combine(root, "index.html");
            string edge86 = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Microsoft", "Edge", "Application", "msedge.exe");
            string edge64 = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Microsoft", "Edge", "Application", "msedge.exe");
            string edge = File.Exists(edge86) ? edge86 : edge64;

            if (File.Exists(edge))
            {
                string url = new Uri(index).AbsoluteUri;
                Process.Start(new ProcessStartInfo(edge, "--app=\"" + url + "\" --allow-file-access-from-files --start-maximized") { UseShellExecute = true });
            }
            else
            {
                Process.Start(new ProcessStartInfo(index) { UseShellExecute = true });
            }
        }
        catch (Exception error)
        {
            System.Windows.Forms.MessageBox.Show(error.Message, "DeltaMap 启动失败", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
        }
    }
}
