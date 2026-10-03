# 📊 Vendas Online vs. Outros Canais - Devemos Investir Mais no Digital?

Solução de Business Intelligence desenvolvida para subsidiar a decisão da diretoria sobre o aumento de investimento no canal digital, comparando o desempenho do e-commerce frente aos demais canais de venda em faturamento, ticket médio, volume de transações e comportamento de compra.

<br>

## 🎯 Sobre o Projeto

Este painel foi estruturado para responder a uma pergunta de negócio direta: **o canal Online tem desempenho suficiente para justificar mais investimento, ou os recursos devem continuar concentrados nos canais tradicionais?**

A análise utiliza a base de demonstração **ContosoRetailDW** (Microsoft), unificando duas tabelas fato de origens distintas — vendas digitais e vendas dos demais canais — em um modelo único, permitindo comparação justa entre eles.

### 🌟 Principais Destaques:
- **Narrativa orientada à decisão:** estrutura em 3 páginas que seguem a lógica conclusão → evidência → tendência, facilitando a leitura por um público gerencial não técnico.
- **Unificação de múltiplas fontes:** tratamento de duas tabelas fato com granularidades e estruturas diferentes em uma única base analítica.
- **Medidas DAX avançadas:** comparação com período anterior, crescimento % YoY, acumulado YTD, participação de mercado dinâmica e ranking.
- **Identidade visual proposital:** paleta de cores que destaca o canal Online como protagonista da análise, mantendo os demais canais como contexto comparativo.
- **Formatação condicional:** alertas visuais automáticos para percentual de devolução por canal.

<br>

---

## 🗂️ Fonte de Dados

| Tabela | Papel | Principais Colunas |
|---|---|---|
| `FactOnlineSales` | Fato — vendas do canal digital | DateKey, ProductKey, CustomerKey, SalesQuantity, SalesAmount, ReturnAmount |
| `FactSales` | Fato — vendas dos demais canais | DateKey, ChannelKey, ProductKey, SalesQuantity, SalesAmount, ReturnAmount |
| `DimChannel` | Dimensão — canal de venda | ChannelKey, ChannelName |
| `DimDate` | Dimensão — calendário | DateKey, CalendarYear, MonthNumberOfYear |

**Período analisado:** 2007 a 2009. Os anos de 2005, 2006, 2010 e 2011 foram excluídos do escopo por apresentarem volume de dados insuficiente para uma comparação estatisticamente relevante entre os canais — uma escolha deliberada de recorte, não uma limitação da base.

<br>

---

## 🗄️ Camada SQL — Consulta Unificada de Canais

Antes de qualquer modelagem no Power BI, a primeira etapa do projeto foi validar a comparação entre canais diretamente no SQL Server — tanto para entender a estrutura dos dados quanto para conferir, de forma independente, os números que posteriormente seriam reproduzidos no modelo de BI.

A query abaixo unifica `FactOnlineSales` e `FactSales` (via `JOIN` com `DimChannel`) usando `UNION ALL`, trazendo faturamento total, ticket médio e total de transações por canal:

```sql
USE ContosoRetailDW

SELECT 'Online' AS canal, 
COUNT(*)               AS total_transacoes, 
SUM(SalesAmount)       AS faturamento_total, 
AVG(SalesAmount)       AS ticket_medio 
FROM FactOnlineSales 
UNION ALL 
SELECT c.ChannelName, 
COUNT(*)               AS total_transacoes, 
SUM(f.SalesAmount)     AS faturamento_total, 
AVG(f.SalesAmount)     AS ticket_medio 
FROM FactSales f 
JOIN DimChannel c ON c.ChannelKey = f.channelKey 
GROUP BY c.ChannelName 
ORDER BY faturamento_total DESC;

```

Essa consulta serviu como **ponto de verdade inicial**: os totais obtidos aqui foram usados posteriormente para validar se as medidas DAX criadas no Power BI (faturamento, ticket médio, transações) batiam com o que o SQL já havia calculado de forma independente — uma prática importante para garantir confiabilidade no dashboard final.



<br>

---

## 🛠️ Arquitetura e Engenharia de Dados

### Unificação dos Canais — Decisão Técnica

O modelo original da ContosoRetailDW separa as vendas em duas tabelas fato distintas: `FactOnlineSales`, exclusiva do canal digital, e `FactSales`, que agrupa os demais canais (loja física, revenda, catálogo) via relacionamento com `DimChannel`. Como o objetivo era comparar o canal Online com os demais em pé de igualdade, foi necessário unificar essas fontes antes da modelagem final.

Duas abordagens foram avaliadas: tratar a unificação no SQL Server, via uma `VIEW` com `UNION ALL`, ou realizá-la diretamente no Power BI, via **Power Query (Append Queries)**. A segunda abordagem foi a escolhida, por dois motivos:

1. **Realismo operacional:** reflete um cenário comum no dia a dia de um analista de BI, que muitas vezes tem apenas permissão de leitura no banco de dados, sem acesso para criação de objetos como *Views*.
2. **Transparência e portabilidade:** mantém todo o pipeline de transformação documentado e auditável dentro do próprio arquivo Power BI, sem dependência de conhecimento prévio do schema do banco por quem for dar manutenção no relatório.

**Como foi feito:** as tabelas `FactOnlineSales` e `FactSales` foram importadas separadamente. Na primeira, foi adicionada uma coluna customizada `Tipo`, fixada como `"Online"`. Na segunda, foi realizado um `Merge` com `DimChannel` para trazer o nome de cada canal físico, padronizando a coluna também como `Tipo`. Em seguida, aplicou-se `Append Queries as New` para unificar as duas em uma única tabela fato, `Vendas_Unificadas`. As queries intermediárias tiveram o carregamento desabilitado (*Enable Load*), permanecendo apenas como passos de transformação — sem gerar tabelas duplicadas no modelo final.

> *Trade-off consciente: essa abordagem tem custo de performance em bases muito grandes, já que a transformação ocorre no momento do refresh dentro do Power BI, em vez de aproveitar o processamento otimizado do SQL Server. Para o escopo deste projeto, esse custo foi considerado aceitável frente ao ganho de portabilidade e transparência do processo.*

<br>

## 📐 Modelagem de Dados (Star Schema)

O modelo final segue um star schema simples, com uma fato central e duas dimensões:

```
        DimDate
           |
    Vendas_Unificadas (fato única)
           |
       DimChannel (atributos complementares)
```

| Relacionamento | Cardinalidade | Direção do filtro |
|---|---|---|
| `Vendas_Unificadas[DateKey]` → `DimDate[Datekey]` | Muitos-para-um (N:1) | Único sentido |
| `Vendas_Unificadas[Tipo]` → `DimChannel[ChannelName]` | Muitos-para-um (N:1) | Único sentido |

A tabela `DimDate` foi marcada como *Date Table*, habilitando as funções de time intelligence utilizadas nas medidas de evolução temporal.

<br>

---

## 🧮 Medidas DAX — Destaques

Além das medidas básicas de agregação (faturamento, ticket médio, quantidade de transações), o modelo inclui medidas avançadas que sustentam a narrativa analítica:

- **Comparação com período anterior** (`DATEADD`, `SAMEPERIODLASTYEAR`) — compara o desempenho do mês/ano atual com o mesmo período anterior.
- **Crescimento % YoY** — taxa de crescimento ano a ano, por canal, usada como principal indicador de tendência.
- **Faturamento YTD** (`TOTALYTD`) — acumulado do ano, dando visão de progresso menos sensível à sazonalidade mensal.
- **Participação de mercado dinâmica** (`CALCULATE` + `ALL`) — percentual que cada canal representa do total, recalculado conforme os filtros ativos no relatório.
- **Medidas de contexto fixo** (ex: `Faturamento Online`, `Crescimento % YoY Online`) — usando `CALCULATE` com filtro de canal fixado, para KPIs de referência que não variam conforme o usuário interage com os slicers.
- **Ranking dinâmico** (`RANKX`) — posição de cada canal/produto frente aos demais, considerando o universo completo independente do filtro aplicado.
- **Devolução por transação** — além do percentual financeiro de devolução, foi criada uma métrica de frequência (quantas transações tiveram devolução), por ser mais intuitiva para leitura gerencial.

<br>

---

## 1️⃣ Página 1 — Visão Geral

Responde à pergunta central em poucos segundos de leitura: o tamanho atual do canal Online e sua trajetória de crescimento.
- **Cartões de KPI:** Faturamento Total, Faturamento Online, Participação de Mercado Online e Crescimento % YoY Online (este último em destaque visual).
- **Gráfico de rosca:** participação de mercado por canal, com o Online destacado em cor própria frente aos demais canais em tons neutros.
- **Síntese textual dinâmica:** frase gerada a partir de medidas DAX, atualizando automaticamente os números conforme os filtros aplicados.

<p align="center">
  <img src="SUBSTITUA_PELA_URL_DA_IMAGEM_PAGINA_1" alt="Página 1 - Visão Geral" width="100%">
</p>

<br>

---

## 2️⃣ Página 2 — Comparativo de Canais

Aprofunda o "porquê" por trás dos números da Página 1, expondo o padrão de comportamento de compra entre canais.
- **Matriz comparativa:** faturamento, ticket médio, quantidade de transações e percentual de devolução, lado a lado por canal.
- **Formatação condicional:** escala de cor automática na coluna de devolução, sinalizando risco operacional sem necessidade de leitura detalhada.
- **Gráfico combinado (barras + linha):** contrasta visualmente ticket médio e volume de transações — o insight central desta página.
- **Insight textual:** o canal Online realiza significativamente mais transações que os demais canais, com ticket médio menor — padrão típico de comportamento de compra em e-commerce.

<p align="center">
  <img src="SUBSTITUA_PELA_URL_DA_IMAGEM_PAGINA_2" alt="Página 2 - Comparativo de Canais" width="100%">
</p>

<br>

---

## 3️⃣ Página 3 — Evolução Temporal

Fecha a narrativa mostrando a direção da tendência ao longo do tempo, não apenas uma fotografia do presente.
- **Gráfico de linhas:** faturamento mensal por canal entre 2007 e 2009, com o Online destacado visualmente (cor e espessura) sobre os demais.
- **Linha de referência:** média do período, para calibrar rapidamente se um mês está acima ou abaixo do histórico.
- **Gráfico de crescimento % YoY:** comparação direta da taxa de crescimento entre canais, com cores condicionais (positivo/negativo).
- **Cartões de Faturamento YTD:** acumulado do ano por canal.

<p align="center">
  <img src="SUBSTITUA_PELA_URL_DA_IMAGEM_PAGINA_3" alt="Página 3 - Evolução Temporal" width="100%">
</p>

<br>

---

## 🎨 Identidade Visual

A paleta foi definida para que o canal Online seja sempre o protagonista visual — único canal com cor de destaque (azul), enquanto os demais permanecem em tons neutros de cinza. Verde, vermelho e âmbar foram reservados exclusivamente para formatação condicional (crescimento, devolução), nunca como identidade fixa de canal, evitando que a mesma cor significasse coisas diferentes em pontos distintos do dashboard.

<br>

---

## 💡 Insight Final e Recomendação à Diretoria

> ⚠️ *Antes de publicar, substitua os valores entre colchetes pelos números reais, já validados no seu modelo.*

Com base na análise do período de 2007 a 2009, o canal Online representa **[XX]%** do faturamento total da companhia, com crescimento de **[XX]%** no último ano — ritmo **[superior/inferior]** ao dos demais canais combinados. Apesar de um ticket médio **[XX]%** menor que o canal físico, o Online compensa essa diferença com um volume de transações **[X]x maior**, sustentando um faturamento absoluto relevante e em trajetória de crescimento.

O principal ponto de atenção identificado é o percentual de devolução do canal digital, **[XX]%**, superior à média dos demais canais — um risco operacional típico de e-commerce que deve ser monitorado, mas que não invalida o argumento de crescimento.

**Recomendação:** os dados sustentam a tese de que o canal Online não é apenas relevante em volume de transações, mas também está em trajetória de crescimento consistente frente aos canais tradicionais. Diante disso, recomenda-se **[inserir recomendação final: aumentar o investimento no digital / manter o investimento atual com monitoramento de devolução / etc.]**, com acompanhamento trimestral dos indicadores aqui apresentados para validar a tendência ao longo do tempo.

<br>

---

## 🛠️ Tecnologias Utilizadas

| Categoria | Ferramenta |
|---|---|
| Banco de Dados | Microsoft SQL Server |
| Base de Dados | ContosoRetailDW |
| ETL / Transformação | Power Query (M) |
| Modelagem e Visualização | Microsoft Power BI |
| Linguagem de Cálculo | DAX |

<br>

## 🧠 Desafios Técnicos Enfrentados

Alguns obstáculos encontrados durante o desenvolvimento, documentados aqui por reforçarem o processo real de construção do projeto (não só o resultado final):

- **Inconsistência de tipos de dado entre fato e dimensão:** a coluna de data em uma das tabelas estava como texto, exigindo conversão explícita antes de estabelecer o relacionamento.
- **Calendário não contíguo:** a tabela `DimDate` original não continha todos os dias do período (fins de semana ausentes), o que quebra funções de time intelligence como `SAMEPERIODLASTYEAR` — ponto de atenção documentado para eventual criação de uma tabela calendário auxiliar completa.
- **Ordenação de meses por nome:** como a base não possuía uma coluna numérica de mês pronta, foi necessário criar uma coluna calculada (`MONTH()`) e aplicar *Sort by Column* para garantir a ordem cronológica correta nos eixos dos gráficos.
- **Nomenclatura de canais:** os valores da coluna `ChannelName` vieram em inglês (*Catalog, Online, Reseller, Store*), exigindo atenção redobrada ao escrever medidas DAX com filtros de texto fixo, para evitar comparações que retornassem valores vazios silenciosamente.

<br>

## 👨‍💻 Autor

Desenvolvido por **Mateus Ferreira**.
Se este projeto te inspirou, sinta-se à vontade para se conectar comigo no LinkedIn!

<p>
  <a href="https://www.linkedin.com/in/mateus-ferreira-data-analytics" target="_blank">
    <img align="center" alt="LinkedIn" height="40" width="40" src="https://github.com/BruceFonseca/Portfolio/blob/main/social%20icons/linkedin.png?raw=true">
  </a>
</p>
