using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.ApplicationServices.Core;
using Autodesk.AutoCAD.EditorInput;

[assembly: ExtensionApplication(typeof(SpePluginMinimo.Plugin))]

namespace SpePluginMinimo
{
    public class Plugin : IExtensionApplication
    {
        public void Initialize()
        {
            // Nada — só testa se carrega sem travar
        }

        public void Terminate() { }
    }

    public class Comandos
    {
        [CommandMethod("SPE_TESTE")]
        public void Teste()
        {
            var doc = Application.DocumentManager.MdiActiveDocument;
            doc?.Editor.WriteMessage("\nSPE Plugin funcionando!\n");
        }
    }
}
