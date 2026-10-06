using WinForms = System.Windows.Forms;
using Drawing = System.Drawing;

namespace SpePlugin.Servicos
{
    /// <summary>
    /// Janela de login do plugin (e-mail + senha mascarada).
    /// </summary>
    public static class LoginDialog
    {
        /// <summary>
        /// Mostra a janela. Retorna null se o usuário cancelar.
        /// </summary>
        public static (string Email, string Senha)? Mostrar(string emailInicial, string? erro)
        {
            using var form = new WinForms.Form
            {
                Text = "SPE - Entrar",
                FormBorderStyle = WinForms.FormBorderStyle.FixedDialog,
                StartPosition = WinForms.FormStartPosition.CenterScreen,
                MaximizeBox = false,
                MinimizeBox = false,
                ShowInTaskbar = false,
                ClientSize = new Drawing.Size(340, erro == null ? 170 : 200),
            };

            int y = 14;
            if (erro != null)
            {
                form.Controls.Add(new WinForms.Label
                {
                    Text = erro,
                    ForeColor = Drawing.Color.Firebrick,
                    Left = 14, Top = y, Width = 312, Height = 28,
                });
                y += 30;
            }

            form.Controls.Add(new WinForms.Label { Text = "E-mail", Left = 14, Top = y, Width = 312 });
            var txtEmail = new WinForms.TextBox { Text = emailInicial, Left = 14, Top = y + 20, Width = 312 };
            form.Controls.Add(txtEmail);

            form.Controls.Add(new WinForms.Label { Text = "Senha", Left = 14, Top = y + 50, Width = 312 });
            var txtSenha = new WinForms.TextBox { Left = 14, Top = y + 70, Width = 312, UseSystemPasswordChar = true };
            form.Controls.Add(txtSenha);

            var btnEntrar = new WinForms.Button
            {
                Text = "Entrar", Left = 170, Top = y + 106, Width = 75, DialogResult = WinForms.DialogResult.OK,
            };
            var btnCancelar = new WinForms.Button
            {
                Text = "Cancelar", Left = 251, Top = y + 106, Width = 75, DialogResult = WinForms.DialogResult.Cancel,
            };
            form.Controls.Add(btnEntrar);
            form.Controls.Add(btnCancelar);
            form.AcceptButton = btnEntrar;
            form.CancelButton = btnCancelar;
            form.Shown += (_, _) => (string.IsNullOrEmpty(txtEmail.Text) ? txtEmail : txtSenha).Focus();

            var resultado = Autodesk.AutoCAD.ApplicationServices.Application.ShowModalDialog(form);
            if (resultado != WinForms.DialogResult.OK) return null;
            if (string.IsNullOrWhiteSpace(txtEmail.Text) || string.IsNullOrEmpty(txtSenha.Text)) return null;
            return (txtEmail.Text, txtSenha.Text);
        }
    }
}
