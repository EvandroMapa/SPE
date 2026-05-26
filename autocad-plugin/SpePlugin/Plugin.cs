using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.ApplicationServices.Core;

[assembly: ExtensionApplication(typeof(SpePlugin.Plugin))]

namespace SpePlugin
{
    /// <summary>
    /// Entry point do plugin SPE para AutoCAD 2025.
    /// Carregado automaticamente via NETLOAD.
    /// </summary>
    public class Plugin : IExtensionApplication
    {
        public void Initialize()
        {
            try
            {
                // Carregar configuração salva (URL + Key do Supabase)
                Servicos.ConfigService.Carregar();

                // Mostrar banner — MdiActiveDocument pode ser null durante NETLOAD
                var doc = Application.DocumentManager?.MdiActiveDocument;
                if (doc != null)
                {
                    doc.Editor.WriteMessage("\n======================================");
                    doc.Editor.WriteMessage("\n   SPE Plugin v2.1 - Carregado!      ");
                    doc.Editor.WriteMessage("\n   SPE       — clique a clique       ");
                    doc.Editor.WriteMessage("\n   SPE_BLOCO — selecao por area      ");
                    doc.Editor.WriteMessage("\n======================================\n");
                }
            }
            catch
            {
                // Silencioso — não travar o AutoCAD se algo falhar na inicialização
            }
        }

        public void Terminate()
        {
            // Cleanup se necessário
        }
    }
}
