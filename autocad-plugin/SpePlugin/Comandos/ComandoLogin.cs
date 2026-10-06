using Autodesk.AutoCAD.ApplicationServices.Core;
using Autodesk.AutoCAD.Runtime;
using SpePlugin.Servicos;

namespace SpePlugin.Comandos
{
    /// <summary>
    /// SPE_LOGIN — entra (ou troca de usuário) com o mesmo login do app SPE.
    /// SPE_SAIR  — sai e apaga o login salvo neste computador.
    /// </summary>
    public class ComandoLogin
    {
        [CommandMethod("SPE_LOGIN")]
        public void Entrar()
        {
            var ed = Application.DocumentManager.MdiActiveDocument.Editor;
            try
            {
                if (AuthService.PedirLogin())
                {
                    SessaoAtual.DadosCarregados = false; // recarrega bitolas/formas com o novo login
                    ed.WriteMessage($"\n[OK] Conectado como {AuthService.EmailAtual}\n");
                }
                else
                {
                    ed.WriteMessage("\n[CANCELADO]\n");
                }
            }
            catch (System.Exception ex)
            {
                ed.WriteMessage($"\n[ERRO] {ex.Message}\n");
            }
        }

        [CommandMethod("SPE_SAIR")]
        public void Sair()
        {
            var ed = Application.DocumentManager.MdiActiveDocument.Editor;
            AuthService.Sair();
            SessaoAtual.DadosCarregados = false;
            ed.WriteMessage("\n[OK] Login removido deste computador. O proximo comando SPE pedira login.\n");
        }
    }
}
