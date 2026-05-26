using Autodesk.AutoCAD.ApplicationServices.Core;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;
using SpePlugin.Servicos;
using System.Text.Json;

namespace SpePlugin.Comandos
{
    /// <summary>
    /// SPE — Comando único para captura dinâmica de armaduras.
    /// Fluxo: busca planilha → confirma → clica elemento → clica posições → ESC salva → repete.
    /// </summary>
    public class ComandoCaptura
    {
        [CommandMethod("SPE")]
        public void Executar()
        {
            var doc = Application.DocumentManager.MdiActiveDocument;
            var ed = doc.Editor;

            ed.WriteMessage("\n======================================");
            ed.WriteMessage("\n   SPE - Captura de Armaduras         ");
            ed.WriteMessage("\n======================================\n");

            // 1. Carregar dados de referência
            SupabaseClient? client = null;
            try
            {
                client = new SupabaseClient();
                if (!SessaoAtual.DadosCarregados)
                {
                    ed.WriteMessage("\nCarregando dados do Supabase...");
                    SessaoAtual.Bitolas = client.ListarBitolas();
                    SessaoAtual.Formas = client.ListarFormas();
                    SessaoAtual.DadosCarregados = true;
                    ed.WriteMessage($" [OK]\n");
                }
            }
            catch (System.Exception ex)
            {
                ed.WriteMessage($"\n[ERRO] Falha ao conectar: {ex.Message}\n");
                return;
            }

            // 2. Buscar planilha (detalhamento) existente
            string detalhamentoId;
            string nomePlanilha;

            while (true)
            {
                var opBusca = new PromptStringOptions("\nNome ou codigo do detalhamento: ");
                opBusca.AllowSpaces = true;
                var resBusca = ed.GetString(opBusca);
                if (resBusca.Status != PromptStatus.OK || string.IsNullOrWhiteSpace(resBusca.StringResult))
                {
                    ed.WriteMessage("\n[CANCELADO]\n");
                    return;
                }

                var termoBusca = resBusca.StringResult.Trim();

                // Buscar no Supabase
                ed.WriteMessage($"\n  Buscando \"{termoBusca}\"...");
                try
                {
                    var resultados = client!.BuscarDetalhamentos(termoBusca);

                    if (resultados.Count == 0)
                    {
                        ed.WriteMessage($"\n  [!] Nenhuma planilha encontrada com \"{termoBusca}\".");
                        ed.WriteMessage($"\n  Tente novamente ou ESC para cancelar.\n");
                        continue;
                    }

                    // Mostrar resultados
                    ed.WriteMessage($"\n  {resultados.Count} resultado(s):\n");
                    for (int i = 0; i < resultados.Count; i++)
                    {
                        var r = resultados[i];
                        var cod = ExtrairString(r, "codigo");
                        var clienteNome = ExtrairString(r, "cliente_nome");
                        var obraNome = ExtrairString(r, "obra_nome");
                        ed.WriteMessage($"\n  [{i + 1}] #{cod} - {clienteNome} / {obraNome}");
                    }
                    ed.WriteMessage("\n");

                    // Escolher
                    if (resultados.Count == 1)
                    {
                        var r = resultados[0];
                        var cod = ExtrairString(r, "codigo");
                        var clienteNome = ExtrairString(r, "cliente_nome");
                        var obraNome = ExtrairString(r, "obra_nome");

                        var opConf = new PromptKeywordOptions(
                            $"\n  #{cod} - {clienteNome} / {obraNome}. Correto? [Sim/Nao]: ", "Sim Nao");
                        opConf.Keywords.Default = "Sim";
                        var resConf = ed.GetKeywords(opConf);
                        if (resConf.Status != PromptStatus.OK || resConf.StringResult == "Nao")
                        {
                            ed.WriteMessage("\n  Tente outro nome.\n");
                            continue;
                        }

                        detalhamentoId = ExtrairString(r, "id");
                        nomePlanilha = $"#{cod} - {clienteNome} / {obraNome}";
                    }
                    else
                    {
                        var opEscolha = new PromptIntegerOptions("\n  Numero da planilha: ");
                        opEscolha.LowerLimit = 1;
                        opEscolha.UpperLimit = resultados.Count;
                        var resEscolha = ed.GetInteger(opEscolha);
                        if (resEscolha.Status != PromptStatus.OK)
                        {
                            ed.WriteMessage("\n  Tente outro nome.\n");
                            continue;
                        }

                        var escolhido = resultados[resEscolha.Value - 1];
                        var cod = ExtrairString(escolhido, "codigo");
                        var clienteNome = ExtrairString(escolhido, "cliente_nome");
                        var obraNome = ExtrairString(escolhido, "obra_nome");

                        detalhamentoId = ExtrairString(escolhido, "id");
                        nomePlanilha = $"#{cod} - {clienteNome} / {obraNome}";
                    }

                    ed.WriteMessage($"\n[OK] Planilha selecionada: {nomePlanilha}\n");
                    break;
                }
                catch (System.Exception ex)
                {
                    ed.WriteMessage($"\n  [ERRO] {ex.Message}\n");
                    continue;
                }
            }

            // 3. Loop principal: elemento → posições → salva → repete
            int totalElementos = 0;
            int totalPosicoes = 0;

            while (true)
            {
                ed.WriteMessage("\n--------------------------------------");
                ed.WriteMessage("\n Clique no NOME DO ELEMENTO (V101, P1...)");
                ed.WriteMessage("\n ESC para finalizar.");
                ed.WriteMessage("\n--------------------------------------\n");

                // 3a. Selecionar texto do elemento
                var nomeElemento = SelecionarTexto(doc, ed, "Clique no nome do elemento (ESC = finalizar): ");
                if (nomeElemento == null) break;

                nomeElemento = nomeElemento.Trim().ToUpper();
                ed.WriteMessage($"\n[OK] Elemento: {nomeElemento}\n");

                // 3b. Quantidade
                var opQtd = new PromptIntegerOptions($"\nQuantidade de {nomeElemento} [1]: ");
                opQtd.DefaultValue = 1;
                opQtd.LowerLimit = 1;
                opQtd.UpperLimit = 999;
                var resQtd = ed.GetInteger(opQtd);
                int quantidade = resQtd.Status == PromptStatus.OK ? resQtd.Value : 1;

                // 3c. Coletar posições
                var posicoes = new List<Modelos.Posicao>();

                ed.WriteMessage($"\n  Clique nas POSICOES de {nomeElemento}.");
                ed.WriteMessage($"\n  ESC para salvar e ir ao proximo.\n");

                while (true)
                {
                    var textoPosicao = SelecionarTexto(doc, ed, $"Posicao de {nomeElemento} (ESC = salvar): ");
                    if (textoPosicao == null) break;

                    var parseado = ExtratorTexto.TentarParsearPosicao(textoPosicao);
                    if (parseado == null)
                    {
                        ed.WriteMessage($"\n  [!] \"{textoPosicao}\" - nao reconhecido. Formato: \"2 N35 o12.5 C=415\"\n");
                        continue;
                    }

                    var bitola = SessaoAtual.EncontrarBitola(parseado.BitolaMm);

                    // Mostrar dados extraídos
                    ed.WriteMessage($"\n  N{parseado.NumeroPosicao} | {parseado.Quantidade}x | o{parseado.BitolaMm}mm | C={parseado.Comprimento}");

                    // Montar keywords com os códigos das formas
                    var codigos = new List<string>();
                    foreach (var fm in SessaoAtual.Formas)
                    {
                        var fCod = ExtrairString(fm, "codigo");
                        if (string.IsNullOrEmpty(fCod)) fCod = ExtrairString(fm, "nome");
                        if (!string.IsNullOrEmpty(fCod))
                            codigos.Add(fCod);
                    }

                    string formaId = "";
                    string formaCodigo = codigos.Count > 0 ? codigos[0] : "1";

                    if (codigos.Count > 0)
                    {
                        var opForma = new PromptKeywordOptions(
                            $"\n  Escolha a forma [{codigos[0]}]: ");
                        foreach (var c in codigos)
                            opForma.Keywords.Add(c);
                        opForma.Keywords.Default = codigos[0];
                        opForma.AllowNone = true;

                        var resForma = ed.GetKeywords(opForma);
                        string codDigitado = resForma.Status == PromptStatus.OK
                            ? resForma.StringResult.Trim()
                            : codigos[0];

                        var formaEncontrada = SessaoAtual.EncontrarForma(codDigitado);
                        if (formaEncontrada != null)
                        {
                            formaId = formaEncontrada.Value.id;
                            formaCodigo = formaEncontrada.Value.codigo;
                        }
                        else
                        {
                            ed.WriteMessage($"\n  [!] Forma '{codDigitado}' nao encontrada — usando {codigos[0]}.");
                            var f1 = SessaoAtual.EncontrarForma(codigos[0]);
                            if (f1 != null)
                            {
                                formaId = f1.Value.id;
                                formaCodigo = f1.Value.codigo;
                            }
                        }
                    }

                    var posicao = new Modelos.Posicao
                    {
                        NumeroPosicao = parseado.NumeroPosicao,
                        Quantidade = parseado.Quantidade,
                        BitolaMm = parseado.BitolaMm,
                        BitolaId = bitola?.id ?? "",
                        BitolaNome = bitola?.nome ?? $"o{parseado.BitolaMm}",
                        FormaCodigo = formaCodigo,
                        FormaId = formaId,
                        Comprimentos = parseado.Comprimento > 0
                            ? new Dictionary<string, int> { ["A"] = parseado.Comprimento }
                            : new Dictionary<string, int>(),
                    };

                    posicoes.Add(posicao);
                    ed.WriteMessage($"  [+] N{parseado.NumeroPosicao} {parseado.Quantidade}x o{parseado.BitolaMm} {formaCodigo} C={parseado.Comprimento}  ({posicoes.Count} total)\n");
                }

                if (posicoes.Count == 0)
                {
                    ed.WriteMessage($"\n  [!] {nomeElemento} sem posicoes - ignorado.\n");
                    continue;
                }

                // 3d. Salvar no Supabase
                try
                {
                    ed.WriteMessage($"\n  Salvando {nomeElemento}...");
                    ed.WriteMessage($"\n    detalhamento_id: {detalhamentoId}");

                    var elemMap = new Dictionary<string, object?>
                    {
                        ["nome"] = nomeElemento,
                        ["quantidade"] = quantidade,
                        ["peso_total"] = 0,
                        ["detalhamento_id"] = detalhamentoId,
                        ["elementos_equivalentes"] = new List<string>(),
                    };

                    ed.WriteMessage($"\n    POST elemento...");
                    var elementoId = client!.CriarElemento(elemMap);
                    ed.WriteMessage($" id={elementoId}");

                    if (string.IsNullOrEmpty(elementoId))
                    {
                        ed.WriteMessage("\n    [ERRO] Elemento nao retornou ID!");
                        continue;
                    }

                    int posSalvas = 0;
                    foreach (var pos in posicoes)
                    {
                        var posMap = pos.ToSupabaseMap(elementoId);
                        posMap.Remove("id");
                        ed.WriteMessage($"\n    POST posicao N{pos.NumeroPosicao}...");
                        var posId = client.CriarPosicao(posMap);
                        ed.WriteMessage($" id={posId}");
                        posSalvas++;
                    }

                    totalElementos++;
                    totalPosicoes += posSalvas;

                    // Dispara Realtime no Flutter — toca o detalhamento pra notificar
                    client.TocarDetalhamento(detalhamentoId);
                    ed.WriteMessage($"\n  [OK] {nomeElemento}: {posSalvas} posicoes salvas! (Realtime enviado)\n");
                }
                catch (System.Exception ex)
                {
                    ed.WriteMessage($"\n  [ERRO] {ex.Message}");
                    if (ex.InnerException != null)
                        ed.WriteMessage($"\n    Inner: {ex.InnerException.Message}");
                    ed.WriteMessage("\n");
                }
            }

            // 4. Resumo final
            ed.WriteMessage("\n======================================");
            ed.WriteMessage($"\n  Planilha: {nomePlanilha}");
            ed.WriteMessage($"\n  {totalElementos} elementos, {totalPosicoes} posicoes");
            ed.WriteMessage("\n  Dados ja estao no app Flutter!");
            ed.WriteMessage("\n======================================\n");
        }

        private string? SelecionarTexto(Autodesk.AutoCAD.ApplicationServices.Document doc, Editor ed, string mensagem)
        {
            var opEnt = new PromptEntityOptions($"\n{mensagem}");
            opEnt.SetRejectMessage("\n[!] Selecione TEXT ou MTEXT.");
            opEnt.AddAllowedClass(typeof(DBText), true);
            opEnt.AddAllowedClass(typeof(MText), true);
            var resEnt = ed.GetEntity(opEnt);

            if (resEnt.Status != PromptStatus.OK) return null;

            string texto = "";
            using (var tr = doc.TransactionManager.StartTransaction())
            {
                var ent = tr.GetObject(resEnt.ObjectId, OpenMode.ForRead);
                if (ent is DBText dbText)
                    texto = dbText.TextString;
                else if (ent is MText mText)
                    texto = mText.Text;
                tr.Commit();
            }

            return string.IsNullOrWhiteSpace(texto) ? null : texto;
        }

        private static string ExtrairString(Dictionary<string, object?> dict, string key)
        {
            if (!dict.TryGetValue(key, out var val)) return "";
            if (val is JsonElement je) return je.ToString();
            return val?.ToString() ?? "";
        }
    }
}
