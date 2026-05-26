using Autodesk.AutoCAD.ApplicationServices.Core;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;
using SpePlugin.Servicos;
using System.Text.Json;

namespace SpePlugin.Comandos
{
    /// <summary>
    /// SPE_BLOCO — Seleciona uma área inteira e extrai elemento + posições automaticamente.
    /// Fluxo: busca detalhamento → seleciona área → lê todos os textos → identifica elemento + posições → salva.
    /// </summary>
    public class ComandoBloco
    {
        [CommandMethod("SPEBLOCO")]
        public void Executar()
        {
            var doc = Application.DocumentManager.MdiActiveDocument;
            var ed = doc.Editor;

            ed.WriteMessage("\n======================================");
            ed.WriteMessage("\n   SPE_BLOCO - Captura por Selecao    ");
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

                // Configurações sempre recarregam (podem mudar no app)
                var configs = client.ListarConfiguracoesCad();
                if (configs.ContainsKey("plugin_cad_cor_importacao"))
                    SessaoAtual.CorImportacao = int.TryParse(configs["plugin_cad_cor_importacao"], out var cor) ? cor : 3;
                if (configs.ContainsKey("plugin_cad_marcar_x"))
                    SessaoAtual.MarcarComX = configs["plugin_cad_marcar_x"] == "true";
            }
            catch (System.Exception ex)
            {
                ed.WriteMessage($"\n[ERRO] Falha ao conectar: {ex.Message}\n");
                return;
            }

            // 2. Buscar detalhamento
            string detalhamentoId;
            string nomeDetalhamento;

            while (true)
            {
                var opCodigo = new PromptIntegerOptions("\nCodigo do detalhamento: ");
                opCodigo.AllowNegative = false;
                opCodigo.AllowZero = false;
                var resCodigo = ed.GetInteger(opCodigo);
                if (resCodigo.Status != PromptStatus.OK)
                {
                    ed.WriteMessage("\n[CANCELADO]\n");
                    return;
                }

                var codigo = resCodigo.Value;
                ed.WriteMessage($"\n  Buscando detalhamento #{codigo}...");
                try
                {
                    var resultados = client!.BuscarDetalhamentos(codigo.ToString());
                    if (resultados.Count == 0)
                    {
                        ed.WriteMessage($"\n  [!] Detalhamento #{codigo} nao encontrado.");
                        continue;
                    }

                    var escolhido = resultados[0];
                    nomeDetalhamento = $"#{Str(escolhido, "codigo")} - {Str(escolhido, "cliente_nome")} / {Str(escolhido, "obra_nome")}";
                    
                    var opConf = new PromptKeywordOptions(
                        $"\n  {nomeDetalhamento}. Correto? [Sim/Nao]: ", "Sim Nao");
                    opConf.Keywords.Default = "Sim";
                    var resConf = ed.GetKeywords(opConf);
                    if (resConf.Status != PromptStatus.OK || resConf.StringResult == "Nao") continue;

                    detalhamentoId = Str(escolhido, "id");
                    ed.WriteMessage($"\n[OK] Detalhamento: {nomeDetalhamento}\n");
                    break;
                }
                catch (System.Exception ex)
                {
                    ed.WriteMessage($"\n  [ERRO] {ex.Message}\n");
                    continue;
                }
            }

            // 3. Loop principal: clica elemento → seleciona área das posições → salva
            int totalElementos = 0;
            int totalPosicoes = 0;

            while (true)
            {
                ed.WriteMessage("\n--------------------------------------");
                ed.WriteMessage("\n  1. Clique no NOME DO ELEMENTO");
                ed.WriteMessage("\n  2. Selecione a AREA das posicoes");
                ed.WriteMessage("\n  ESC para finalizar.");
                ed.WriteMessage("\n--------------------------------------\n");

                // 3a. Clicar no nome do elemento
                var nomeElemento = SelecionarTexto(doc, ed, "Clique no nome do elemento (ESC = finalizar): ");
                if (nomeElemento == null)
                {
                    if (totalElementos > 0) break;
                    ed.WriteMessage("\n[CANCELADO]\n");
                    return;
                }

                nomeElemento = nomeElemento.Trim().ToUpper();
                ed.WriteMessage($"\n  Elemento: {nomeElemento}\n");

                // 3b. Quantidade do elemento
                var opQtd = new PromptIntegerOptions($"\n  Quantidade de {nomeElemento} [1]: ");
                opQtd.DefaultValue = 1;
                opQtd.LowerLimit = 1;
                opQtd.UpperLimit = 999;
                var resQtd = ed.GetInteger(opQtd);
                int quantidade = resQtd.Status == PromptStatus.OK ? resQtd.Value : 1;

                // 3c. Gravar elemento imediatamente no banco
                string elementoId = "";
                var posicoesCriadas = new List<string>();

                try
                {
                    var elemMap = new Dictionary<string, object?>
                    {
                        ["nome"] = nomeElemento,
                        ["quantidade"] = quantidade,
                        ["peso_total"] = 0,
                        ["detalhamento_id"] = detalhamentoId,
                        ["elementos_equivalentes"] = new List<string>(),
                    };

                    elementoId = client!.CriarElemento(elemMap);
                    client.TocarDetalhamento(detalhamentoId);

                    if (string.IsNullOrEmpty(elementoId))
                    {
                        ed.WriteMessage("\n  [ERRO] Elemento nao retornou ID!");
                        continue;
                    }
                    ed.WriteMessage($"\n  [✓] Elemento gravado: {nomeElemento}\n");
                }
                catch (System.Exception ex)
                {
                    ed.WriteMessage($"\n  [ERRO] Falha ao gravar elemento: {ex.Message}\n");
                    continue;
                }

                // 3d. Arrastar sobre o elemento para capturar posições
                ed.WriteMessage($"\n  Arraste uma janela sobre {nomeElemento}:");

                var opPt1 = new PromptPointOptions($"\n  Primeiro canto: ");
                var resPt1 = ed.GetPoint(opPt1);
                if (resPt1.Status != PromptStatus.OK)
                {
                    ed.WriteMessage("  [!] Cancelado — apagando elemento.\n");
                    try { client!.ExcluirElemento(elementoId); client.TocarDetalhamento(detalhamentoId); } catch { }
                    continue;
                }

                var opPt2 = new PromptCornerOptions("\n  Segundo canto: ", resPt1.Value);
                var resPt2 = ed.GetCorner(opPt2);
                if (resPt2.Status != PromptStatus.OK)
                {
                    ed.WriteMessage("  [!] Cancelado — apagando elemento.\n");
                    try { client!.ExcluirElemento(elementoId); client.TocarDetalhamento(detalhamentoId); } catch { }
                    continue;
                }

                var filtro = new SelectionFilter(new[]
                {
                    new TypedValue((int)DxfCode.Operator, "<OR"),
                    new TypedValue((int)DxfCode.Start, "TEXT"),
                    new TypedValue((int)DxfCode.Start, "MTEXT"),
                    new TypedValue((int)DxfCode.Operator, "OR>"),
                });

                var resSel = ed.SelectCrossingWindow(resPt1.Value, resPt2.Value, filtro);

                if (resSel.Status != PromptStatus.OK || resSel.Value.Count == 0)
                {
                    ed.WriteMessage("  [!] Nenhum texto na area — apagando elemento.\n");
                    try { client!.ExcluirElemento(elementoId); client.TocarDetalhamento(detalhamentoId); } catch { }
                    continue;
                }

                // 3e. Extrair textos e parsear posições
                var posicoesParseadas = new List<ExtratorTexto.PosicaoParseada>();
                var textosIgnorados = new List<string>();
                var objectIdsParsados = new List<ObjectId>();

                using (var tr = doc.TransactionManager.StartTransaction())
                {
                    foreach (SelectedObject selObj in resSel.Value)
                    {
                        var ent = tr.GetObject(selObj.ObjectId, OpenMode.ForRead);
                        string txt = "";
                        if (ent is DBText dbText) txt = dbText.TextString;
                        else if (ent is MText mText) txt = mText.Text;
                        if (string.IsNullOrWhiteSpace(txt)) continue;

                        txt = txt.Trim();
                        var posParseada = ExtratorTexto.TentarParsearPosicao(txt);
                        if (posParseada != null)
                        {
                            posicoesParseadas.Add(posParseada);
                            objectIdsParsados.Add(selObj.ObjectId);
                        }
                        else
                            textosIgnorados.Add(txt);
                    }
                    tr.Commit();
                }

                // 3f. Mostrar resultado e validar bitolas
                int bitolasNaoEncontradas = 0;
                ed.WriteMessage($"\n  ┌─── {nomeElemento} (qtd: {quantidade}) ──────────\n");
                ed.WriteMessage($"  │ Posicoes encontradas: {posicoesParseadas.Count}\n");

                foreach (var p in posicoesParseadas)
                {
                    var bitola = SessaoAtual.EncontrarBitola(p.BitolaMm);
                    if (bitola != null)
                    {
                        ed.WriteMessage($"  │   N{p.NumeroPosicao}: {p.Quantidade}x {bitola.Value.nome} C={p.Comprimento}\n");
                    }
                    else
                    {
                        bitolasNaoEncontradas++;
                        ed.WriteMessage($"  │   N{p.NumeroPosicao}: {p.Quantidade}x [!] o{p.BitolaMm} NAO CADASTRADA C={p.Comprimento}\n");
                    }
                }

                if (textosIgnorados.Count > 0)
                    ed.WriteMessage($"  │ Ignorados: {textosIgnorados.Count} textos\n");

                ed.WriteMessage("  └─────────────────────────────────\n");

                if (bitolasNaoEncontradas > 0)
                {
                    ed.WriteMessage($"\n  [!] {bitolasNaoEncontradas} bitola(s) nao cadastrada(s) no sistema!");
                    var opCont = new PromptKeywordOptions(
                        "\n  Continuar mesmo assim? [Sim/Nao]: ", "Sim Nao");
                    opCont.Keywords.Default = "Nao";
                    var resCont = ed.GetKeywords(opCont);
                    if (resCont.Status != PromptStatus.OK || resCont.StringResult == "Nao")
                    {
                        ed.WriteMessage("  [!] Apagando elemento e retornando.\n");
                        try { client!.ExcluirPosicoesPorElemento(elementoId); client.ExcluirElemento(elementoId); client.TocarDetalhamento(detalhamentoId); } catch { }
                        continue;
                    }
                }

                if (posicoesParseadas.Count == 0)
                {
                    ed.WriteMessage("  [!] Nenhuma posicao — apagando elemento.\n");
                    try { client!.ExcluirElemento(elementoId); client.TocarDetalhamento(detalhamentoId); } catch { }
                    continue;
                }

                // 3g. Preparar keywords de formas
                var codigos = new List<string>();
                foreach (var fm in SessaoAtual.Formas)
                {
                    var fCod = Str(fm, "codigo");
                    if (string.IsNullOrEmpty(fCod)) fCod = Str(fm, "nome");
                    if (!string.IsNullOrEmpty(fCod))
                        codigos.Add(fCod);
                }

                // 3h. Loop de posições — gravação imediata
                string ultimoFormaCodigo = codigos.Count > 0 ? codigos[0] : "1";
                string ultimoFormaId = "";

                if (codigos.Count > 0)
                {
                    var f1 = SessaoAtual.EncontrarForma(codigos[0]);
                    if (f1 != null)
                    {
                        ultimoFormaId = f1.Value.id;
                        ultimoFormaCodigo = f1.Value.codigo;
                    }
                }

                var posOrdenadas = posicoesParseadas
                    .OrderBy(p => p.NumeroPosicao).ToList();

                try
                {

                    // 3h. Loop de posições — gravação imediata
                    bool cancelarElemento = false;

                    foreach (var p in posOrdenadas)
                    {
                        if (cancelarElemento) break;

                        var bitola = SessaoAtual.EncontrarBitola(p.BitolaMm);
                        var bitolaStr = bitola?.nome ?? $"o{p.BitolaMm}";

                        // Escolher forma ANTES de gravar
                        if (codigos.Count > 0)
                        {
                            var opForma = new PromptKeywordOptions(
                                $"\n  N{p.NumeroPosicao} {p.Quantidade} de {bitolaStr} C={p.Comprimento} → Forma [{ultimoFormaCodigo}]: ");
                            foreach (var c in codigos)
                                opForma.Keywords.Add(c);
                            opForma.Keywords.Default = ultimoFormaCodigo;
                            opForma.AllowNone = true;

                            var resForma = ed.GetKeywords(opForma);
                            if (resForma.Status == PromptStatus.Cancel)
                            {
                                cancelarElemento = true;
                                break;
                            }
                            string codEscolhido = resForma.Status == PromptStatus.OK
                                ? resForma.StringResult.Trim()
                                : ultimoFormaCodigo;

                            var formaEncontrada = SessaoAtual.EncontrarForma(codEscolhido);
                            if (formaEncontrada != null)
                            {
                                ultimoFormaId = formaEncontrada.Value.id;
                                ultimoFormaCodigo = formaEncontrada.Value.codigo;
                            }
                        }

                        // Agora sim criar posição no banco COM a forma já definida
                        var posicao = new Modelos.Posicao
                        {
                            NumeroPosicao = p.NumeroPosicao,
                            Quantidade = p.Quantidade,
                            BitolaMm = p.BitolaMm,
                            BitolaId = bitola?.id ?? "",
                            BitolaNome = bitola?.nome ?? $"o{p.BitolaMm}",
                            FormaCodigo = ultimoFormaCodigo,
                            FormaId = ultimoFormaId,
                            Comprimentos = new Dictionary<string, int>(),
                        };

                        var posMap = posicao.ToSupabaseMap(elementoId);
                        posMap.Remove("id");
                        var posicaoId = client.CriarPosicao(posMap);
                        client.TocarDetalhamento(detalhamentoId);
                        posicoesCriadas.Add(posicaoId);

                        ed.WriteMessage($"\n  N{p.NumeroPosicao} {p.Quantidade}x {bitolaStr}mm forma={ultimoFormaCodigo} — posicao criada");

                        // Capturar trechos com micro-confirmação
                        var trechos = ObterTrechosForma(ultimoFormaCodigo);
                        var comprimentos = new Dictionary<string, int>();

                        if (trechos.Count <= 1)
                        {
                            // Forma simples — usa comprimento do texto se disponível
                            var nomeTrecho = trechos.Count == 1 ? trechos[0].trecho : "A";
                            if (p.Comprimento > 0)
                            {
                                comprimentos[nomeTrecho] = p.Comprimento;
                                client.AtualizarPosicao(posicaoId, new Dictionary<string, object?>
                                {
                                    ["comprimentos"] = comprimentos,
                                });
                                client.TocarDetalhamento(detalhamentoId);
                                ed.WriteMessage($"\n    {nomeTrecho}={p.Comprimento} (do texto)");
                            }
                            else
                            {
                                // Pedir valor com micro-confirmação
                                while (true)
                                {
                                    int val = CapturarValorTrecho(doc, ed, nomeTrecho);
                                    if (val == -1) { cancelarElemento = true; break; }
                                    if (val > 0) comprimentos[nomeTrecho] = val;
                                    else comprimentos.Remove(nomeTrecho);

                                    client.AtualizarPosicao(posicaoId, new Dictionary<string, object?>
                                    {
                                        ["comprimentos"] = comprimentos,
                                    });
                                    client.TocarDetalhamento(detalhamentoId);

                                    var resp = PerguntarConfirmarTrecho(ed, nomeTrecho, val);
                                    if (resp == "Confirmar") break;
                                    if (resp == "Cancelar") { cancelarElemento = true; break; }
                                    // Refazer
                                    comprimentos.Remove(nomeTrecho);
                                    client.AtualizarPosicao(posicaoId, new Dictionary<string, object?>
                                    {
                                        ["comprimentos"] = comprimentos,
                                    });
                                    client.TocarDetalhamento(detalhamentoId);
                                }
                                if (cancelarElemento) break;
                            }
                        }
                        else
                        {
                            // Forma com múltiplos trechos — micro-confirmação por trecho
                            var nomesTrechos = trechos.Select(t => t.trecho).ToList();
                            ed.WriteMessage($"\n    Forma {ultimoFormaCodigo}: {trechos.Count} trechos ({string.Join(", ", nomesTrechos)})");

                            // Mapa grupo → valor já preenchido (para simetria)
                            var valoresPorGrupo = new Dictionary<string, int>();

                            foreach (var (trecho, grupo) in trechos)
                            {
                                if (cancelarElemento) break;

                                // Verificar se é trecho equivalente (mesmo grupo já preenchido)
                                if (!string.IsNullOrEmpty(grupo) && valoresPorGrupo.ContainsKey(grupo))
                                {
                                    int valGrupo = valoresPorGrupo[grupo];
                                    comprimentos[trecho] = valGrupo;
                                    ed.WriteMessage($"\n    ► {trecho}={valGrupo} (= simetria)");

                                    client.AtualizarPosicao(posicaoId, new Dictionary<string, object?>
                                    {
                                        ["comprimentos"] = comprimentos,
                                    });
                                    client.TocarDetalhamento(detalhamentoId);
                                    continue; // pula, já preenchido
                                }

                                while (true)
                                {
                                    int val = CapturarValorTrecho(doc, ed, trecho);
                                    if (val == -1) { cancelarElemento = true; break; }
                                    if (val > 0) comprimentos[trecho] = val;
                                    else comprimentos.Remove(trecho);

                                    client.AtualizarPosicao(posicaoId, new Dictionary<string, object?>
                                    {
                                        ["comprimentos"] = comprimentos,
                                    });
                                    client.TocarDetalhamento(detalhamentoId);

                                    var resp = PerguntarConfirmarTrecho(ed, trecho, val);
                                    if (resp == "Confirmar")
                                    {
                                        if (!string.IsNullOrEmpty(grupo) && val > 0)
                                        {
                                            valoresPorGrupo[grupo] = val;
                                            // Preencher TODOS os simétricos restantes imediatamente
                                            foreach (var (outroTrecho, outroGrupo) in trechos)
                                            {
                                                if (outroTrecho != trecho && outroGrupo == grupo && !comprimentos.ContainsKey(outroTrecho))
                                                {
                                                    comprimentos[outroTrecho] = val;
                                                    ed.WriteMessage($"\n    ► {outroTrecho}={val} (= simetria)");
                                                }
                                            }
                                            client.AtualizarPosicao(posicaoId, new Dictionary<string, object?>
                                            {
                                                ["comprimentos"] = comprimentos,
                                            });
                                            client.TocarDetalhamento(detalhamentoId);
                                        }
                                        break;
                                    }
                                    if (resp == "Cancelar") { cancelarElemento = true; break; }

                                    // Refazer
                                    comprimentos.Remove(trecho);
                                    client.AtualizarPosicao(posicaoId, new Dictionary<string, object?>
                                    {
                                        ["comprimentos"] = comprimentos,
                                    });
                                    client.TocarDetalhamento(detalhamentoId);
                                    ed.WriteMessage($"\n    ↻ Refazendo {trecho}...");
                                }
                            }
                            if (cancelarElemento) break;
                        }

                        ed.WriteMessage($"\n    [✓] N{p.NumeroPosicao} completa!\n");
                    }

                    // Se cancelou durante trechos → cleanup
                    if (cancelarElemento)
                    {
                        ed.WriteMessage($"\n  Cancelando {nomeElemento}...");
                        client.ExcluirPosicoesPorElemento(elementoId);
                        client.ExcluirElemento(elementoId);
                        client.TocarDetalhamento(detalhamentoId);
                        ed.WriteMessage(" [OK] Apagado!\n");
                        continue; // volta pro loop de elementos
                    }

                    // 3i. Final do elemento — Confirmar ou Cancelar
                    ed.WriteMessage($"\n  ── {nomeElemento}: {posicoesCriadas.Count} posicoes ──");
                    var opFinal = new PromptKeywordOptions($"\n  Confirmar elemento {nomeElemento}? [Confirmar/Cancelar]: ");
                    opFinal.Keywords.Add("Confirmar");
                    opFinal.Keywords.Add("Cancelar");
                    opFinal.Keywords.Default = "Confirmar";
                    opFinal.AllowNone = true;

                    var resFinal = ed.GetKeywords(opFinal);
                    string escolhaFinal = resFinal.Status == PromptStatus.OK
                        ? resFinal.StringResult : "Confirmar";

                    if (escolhaFinal == "Cancelar")
                    {
                        // Apagar tudo do banco
                        ed.WriteMessage($"\n  Apagando {nomeElemento} do banco...");
                        client.ExcluirPosicoesPorElemento(elementoId);
                        client.ExcluirElemento(elementoId);
                        client.TocarDetalhamento(detalhamentoId);
                        ed.WriteMessage(" [OK] Cancelado!\n");
                    }
                    else
                    {
                        // Confirmar — marcar textos no CAD
                        totalElementos++;
                        totalPosicoes += posicoesCriadas.Count;
                        ed.WriteMessage($"\n  [✓] {nomeElemento} confirmado! ({posicoesCriadas.Count} posicoes)");

                        // Marcar textos no CAD
                        try
                        {
                            using (var trMark = doc.TransactionManager.StartTransaction())
                            {
                                var btr = (BlockTableRecord)trMark.GetObject(
                                    doc.Database.CurrentSpaceId, OpenMode.ForWrite);
                                int corIdx = SessaoAtual.CorImportacao;

                                foreach (var objId in objectIdsParsados)
                                {
                                    var ent = trMark.GetObject(objId, OpenMode.ForWrite) as Entity;
                                    if (ent != null)
                                        ent.ColorIndex = (short)corIdx;
                                }

                                var p1 = resPt1.Value;
                                var p2 = resPt2.Value;

                                if (SessaoAtual.MarcarComX)
                                {
                                    var linha1 = new Line(
                                        new Autodesk.AutoCAD.Geometry.Point3d(p1.X, p1.Y, 0),
                                        new Autodesk.AutoCAD.Geometry.Point3d(p2.X, p2.Y, 0));
                                    linha1.ColorIndex = (short)corIdx;
                                    var linha2 = new Line(
                                        new Autodesk.AutoCAD.Geometry.Point3d(p1.X, p2.Y, 0),
                                        new Autodesk.AutoCAD.Geometry.Point3d(p2.X, p1.Y, 0));
                                    linha2.ColorIndex = (short)corIdx;
                                    btr.AppendEntity(linha1);
                                    trMark.AddNewlyCreatedDBObject(linha1, true);
                                    btr.AppendEntity(linha2);
                                    trMark.AddNewlyCreatedDBObject(linha2, true);
                                }

                                var midPt = new Autodesk.AutoCAD.Geometry.Point3d(
                                    (p1.X + p2.X) / 2, Math.Max(p1.Y, p2.Y) + 50, 0);
                                var label = new DBText();
                                label.TextString = $"\u2713 {nomeElemento} importado";
                                label.Height = 30;
                                label.ColorIndex = (short)corIdx;
                                label.Position = midPt;
                                label.HorizontalMode = TextHorizontalMode.TextCenter;
                                label.AlignmentPoint = midPt;
                                btr.AppendEntity(label);
                                trMark.AddNewlyCreatedDBObject(label, true);

                                trMark.Commit();
                            }
                            ed.WriteMessage($"\n  [✓] Textos marcados.\n");
                        }
                        catch (System.Exception exMark)
                        {
                            ed.WriteMessage($"\n  [!] Nao marcou textos: {exMark.Message}\n");
                        }
                    }
                }
                catch (System.Exception ex)
                {
                    ed.WriteMessage($"\n  [ERRO] {ex.Message}");
                    if (ex.InnerException != null)
                        ed.WriteMessage($"\n    Inner: {ex.InnerException.Message}");
                    ed.WriteMessage("\n");

                    // Cleanup em caso de erro
                    if (!string.IsNullOrEmpty(elementoId))
                    {
                        try
                        {
                            client!.ExcluirPosicoesPorElemento(elementoId);
                            client.ExcluirElemento(elementoId);
                            client.TocarDetalhamento(detalhamentoId);
                        }
                        catch { }
                    }
                }
            }

            // 4. Resumo final
            ed.WriteMessage("\n======================================");
            ed.WriteMessage($"\n  Detalhamento: {nomeDetalhamento}");
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

        /// <summary>
        /// Micro-confirmação de trecho: "Confirmar", "Refazer" ou "Cancelar".
        /// </summary>
        private string PerguntarConfirmarTrecho(Editor ed, string nomeTrecho, int valor)
        {
            var op = new PromptKeywordOptions($"\n    {nomeTrecho}={valor} — [Confirmar/Refazer/Cancelar]: ");
            op.Keywords.Add("Confirmar");
            op.Keywords.Add("Refazer");
            op.Keywords.Add("Cancelar");
            op.Keywords.Default = "Confirmar";
            op.AllowNone = true;

            var res = ed.GetKeywords(op);
            return res.Status == PromptStatus.OK ? res.StringResult : "Confirmar";
        }

        /// <summary>
        /// Obtém a lista de trechos (nome + grupoSimetria) a partir dos itens da forma.
        /// </summary>
        private List<(string trecho, string grupo)> ObterTrechosForma(string formaCodigo)
        {
            var trechos = new List<(string trecho, string grupo)>();
            foreach (var forma in SessaoAtual.Formas)
            {
                var cod = Str(forma, "codigo");
                if (!string.Equals(cod, formaCodigo, StringComparison.OrdinalIgnoreCase))
                    continue;

                if (forma.TryGetValue("itens", out var itensObj) && itensObj is JsonElement je && je.ValueKind == JsonValueKind.Array)
                {
                    foreach (var item in je.EnumerateArray())
                    {
                        var trecho = item.TryGetProperty("trecho", out var t) ? t.GetString() ?? "A" : "A";
                        var grupo = item.TryGetProperty("grupo_simetria", out var g) ? g.GetString() ?? "" : "";
                        trechos.Add((trecho, grupo));
                    }
                }
                break;
            }
            return trechos;
        }

        /// <summary>
        /// Captura o valor de um trecho: clicar no texto OU digitar valor.
        /// Retorna: >0 = valor, 0 = sem valor, -1 = ESC (cancelar).
        /// </summary>
        private int CapturarValorTrecho(Autodesk.AutoCAD.ApplicationServices.Document doc, Editor ed, string nomeTrecho)
        {
            var opStr = new PromptStringOptions($"\n    ► {nomeTrecho}: valor ou ENTER=clicar [ESC=Cancelar]: ");
            opStr.AllowSpaces = false;

            var resStr = ed.GetString(opStr);

            if (resStr.Status == PromptStatus.Cancel)
                return -1; // ESC

            if (resStr.Status != PromptStatus.OK)
                return 0;

            var input = (resStr.StringResult ?? "").Trim();

            // Digitou um número direto
            if (!string.IsNullOrEmpty(input) && int.TryParse(input, out int valDigitado) && valDigitado > 0)
            {
                ed.WriteMessage($" → {valDigitado}");
                return valDigitado;
            }

            // Enter (vazio) ou texto não-numérico → modo clique
            var opEnt = new PromptEntityOptions($"\n    ► {nomeTrecho}: clique no texto: ");
            opEnt.SetRejectMessage("\n    [!] Selecione TEXT ou MTEXT.");
            opEnt.AddAllowedClass(typeof(DBText), true);
            opEnt.AddAllowedClass(typeof(MText), true);
            opEnt.AllowNone = false;

            var resEnt = ed.GetEntity(opEnt);
            if (resEnt.Status == PromptStatus.OK)
            {
                using (var tr = doc.TransactionManager.StartTransaction())
                {
                    var ent = tr.GetObject(resEnt.ObjectId, OpenMode.ForRead);
                    string texto = "";
                    if (ent is DBText dbText) texto = dbText.TextString;
                    else if (ent is MText mText) texto = mText.Text;
                    tr.Commit();

                    if (!string.IsNullOrWhiteSpace(texto))
                    {
                        var numStr = System.Text.RegularExpressions.Regex.Match(texto.Trim(), @"\d+").Value;
                        if (int.TryParse(numStr, out int val))
                        {
                            ed.WriteMessage($" → {val}");
                            return val;
                        }
                    }
                }
                ed.WriteMessage($"\n    [!] Texto sem numero valido");
                return 0;
            }
            if (resEnt.Status == PromptStatus.Cancel)
                return -1;

            return 0;
        }

        /// <summary>
        /// Busca o texto (DBText ou MText) mais próximo de um ponto clicado.
        /// </summary>
        private string BuscarTextoProximo(Autodesk.AutoCAD.ApplicationServices.Document doc, Autodesk.AutoCAD.Geometry.Point3d ponto)
        {
            string melhorTexto = "";
            double melhorDist = double.MaxValue;

            using (var tr = doc.TransactionManager.StartTransaction())
            {
                var btr = (BlockTableRecord)tr.GetObject(doc.Database.CurrentSpaceId, OpenMode.ForRead);
                foreach (ObjectId objId in btr)
                {
                    var ent = tr.GetObject(objId, OpenMode.ForRead);
                    Autodesk.AutoCAD.Geometry.Point3d pos;
                    string txt;

                    if (ent is DBText dbText)
                    {
                        pos = dbText.Position;
                        txt = dbText.TextString;
                    }
                    else if (ent is MText mText)
                    {
                        pos = mText.Location;
                        txt = mText.Text;
                    }
                    else continue;

                    double dist = ponto.DistanceTo(pos);
                    if (dist < melhorDist)
                    {
                        melhorDist = dist;
                        melhorTexto = txt;
                    }
                }
                tr.Commit();
            }

            return melhorTexto;
        }

        private static string Str(Dictionary<string, object?> dict, string key)
        {
            if (!dict.TryGetValue(key, out var val)) return "";
            if (val is JsonElement je) return je.ToString();
            return val?.ToString() ?? "";
        }
    }
}
