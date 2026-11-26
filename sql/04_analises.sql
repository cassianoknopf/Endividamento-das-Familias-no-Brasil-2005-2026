USE EndividamentoBR

/*

Perguntas de negócio que o painel precisa responder:
1. Como o endividamento das famílias evoluiu de 2005 até hoje? Quais foram os pontos de virada?
2. Quanto desse endividamento vem do crédito habitacional (imobiliário) e quanto do resto (cartão, consignado, pessoal, veículo)?
3. Quanto da renda mensal vai para pagar dívidas? Qual parte é juros e qual é amortização?
4. Houve períodos em que o endividamento caiu, mas o comprometimento de renda subiu? Isso indica crédito mais caro.

*/

-- =========================================================
-- 0. Exploração dos dados
-- Objetivo: conhecer a view antes das análises
-- =========================================================

-- Visão geral da view da base de dados:
SELECT TOP 100 *
FROM dbo.vw_painel_mensal
ORDER BY data_ref;

-- Período coberto e quantidade de meses
SELECT
    MIN(data_ref) AS primeiro_mes,
    MAX(data_ref) AS ultimo_mes,
    COUNT(*)      AS total_meses
FROM dbo.vw_painel_mensal;
--01/01/2005 - 01/11/2026 - 263 meses

-- Meses com dado em cada indicador
-- (COUNT(coluna) ignora NULL; a diferença para COUNT(*) são os meses sem dado)
SELECT
    COUNT(*)                              AS total_meses,
    COUNT(endividamento_total)            AS com_endividamento,
    COUNT(endividamento_sem_habitacional) AS com_endiv_sem_habitacional,
    COUNT(comprometimento_total)          AS com_comprometimento,
    COUNT(comprometimento_juros_estimado) AS com_juros,
    COUNT(comprometimento_amortizacao)    AS com_amortizacao,
    COUNT(inadimplencia_pf)               AS com_inadimplencia,
    COUNT(selic_mensal)                   AS com_selic
FROM dbo.vw_painel_mensal;

/*
Observações:
- A view cobre jan/2005 a nov/2026 (263 meses), mas nem todo indicador tem dado no período inteiro.
- Só a Selic tem dado em todos os meses (janeiro/2005 a novembro/2026).
- Endividamento começa em jan/2005, comprometimento (total, juros e amortização) começa em mar/2005.
  Ambos terminam em ago/2026: o Banco Central publica esses indicadores com alguns meses de atraso.
- Inadimplência PF começa só em mar/2011.
*/

-- =========================================================
-- P1: 
-- Como o endividamento das famílias evoluiu de 2005 até hoje? 
-- Quais foram os pontos de virada?
-- =========================================================

-- Parte 1: evolução (média por ano)

-- Query

SELECT
    c.ano,
    ROUND(AVG(v.endividamento_total), 2)   AS endividamento_medio,
    ROUND(AVG(v.comprometimento_total), 2) AS comprometimento_medio,
    ROUND(AVG(v.inadimplencia_pf), 2)      AS inadimplencia_pf_media,
    ROUND(AVG(v.selic_mensal), 2)          AS selic_media
FROM dbo.vw_painel_mensal v
JOIN dbo.dim_calendario c ON c.data_ref = v.data_ref
GROUP BY c.ano
ORDER BY c.ano;

/*
Parte 1:
- De 2005 a 2015, o endividamento médio subiu todos os anos.
- Entre 2015 e 2017, caiu mais de 2 p.p. 
- Voltou a subir de 37,9% (2018) para 40,5% (2019).
- Entre 2020 e 2022 (pandemia e pós-pandemia), subiu 9 p.p.
- Em 2026, a dívida das famílias equivale, em média, a 49,87% da renda de 12 meses (até ago/2026).
*/

-- Parte 2: pontos de virada

-- Query

-- maiores valores
SELECT TOP 5 data_ref, endividamento_total, comprometimento_total
FROM dbo.vw_painel_mensal
WHERE endividamento_total IS NOT NULL
ORDER BY endividamento_total DESC;

-- menores valores
SELECT TOP 5 data_ref, endividamento_total, comprometimento_total
FROM dbo.vw_painel_mensal
WHERE endividamento_total IS NOT NULL
ORDER BY endividamento_total ASC;

-- queda após o pico de 2022
SELECT data_ref, endividamento_total, comprometimento_total
FROM dbo.vw_painel_mensal
WHERE data_ref BETWEEN '2022-01-01' AND '2024-12-01'
ORDER BY data_ref;

/*
Parte 2:
- Pontos de virada: 2015 (fim de 10 anos de alta), 2017 (retomada), jul/2022 (pico de 49,89%) e set/2024 (menor valor após a queda, −1,75 p.p.).
- Desde set/2024 subiu +1,97 p.p., até o recorde da série: 50,11% em ago/2026.
- Os dois picos têm endividamento quase igual (+0,22 p.p.), mas o comprometimento é 2,49 p.p. maior hoje (28,99% contra 26,50%).
- O menor valor é o do início da série, jan/2005 (16,51%): de lá até hoje, o endividamento triplicou (+33,60 p.p.).
*/


-- =========================================================
-- P2 — Quanto desse endividamento vem do crédito habitacional (imobiliário) e quanto do resto (cartão, consignado, pessoal, veículo)?
-- =========================================================

-- Query

  SELECT TOP 12 data_ref, endividamento_total, endividamento_sem_habitacional
  FROM dbo.vw_painel_mensal
  ORDER BY data_ref DESC;

SELECT
    c.ano,
    ROUND(AVG(v.endividamento_total - v.endividamento_sem_habitacional), 2) AS divida_casa_sobre_renda,
    ROUND(AVG((v.endividamento_total - v.endividamento_sem_habitacional)
              / NULLIF(v.endividamento_total, 0) * 100), 1)                AS divida_casa_sobre_divida_total  -- NULLIF evita divisão por zero
FROM dbo.vw_painel_mensal v
JOIN dbo.dim_calendario c ON c.data_ref = v.data_ref
GROUP BY c.ano
ORDER BY c.ano;

-- Variação % habitacional:

-- Variação da dívida da casa (em relação à renda), 2005 → 2026

SELECT 18.79 - 2.67                   -- +16,12 p.p.
SELECT (18.79 - 2.67) / 2.67 * 100    -- +604% (cerca de 7 vezes maior)

/*
Resposta:
- A dívida da casa passou de 2,67% da renda (2005) para 18,79% (2026): +16,12 p.p., cerca de 7 vezes maior.
- Em 2005, 14,6% de toda a dívida das famílias era da casa (85,4% era o resto: cartão, carro, consignado etc.).
  Em 2026, a casa é 37,7% da dívida (o resto, 62,3%).
- A participação da casa atingiu o máximo em 2017 (42,0% da dívida) e depois recuou: o resto voltou a crescer mais rápido.
*/


-- =========================================================
-- P3: 
-- Quanto da renda mensal vai para pagar dívidas? 
-- Qual parte é juros e qual é amortização?
-- =========================================================

-- Query

-- Parte 1: Quanto da renda mensal vai para pagar dívidas? 

SELECT
    data_ref AS "Período", 
     CAST(comprometimento_total AS DECIMAL(5,2)) AS "% Renda Mensal Comprometida" --a coluna padrão é DECIMAL(10,4), por isso o uso de CAST
FROM vw_painel_mensal
WHERE comprometimento_total IS NOT NULL
ORDER BY comprometimento_total ASC
--ORDER BY comprometimento_total DESC

--P.P

SELECT 28.99 - 17
--11,99

/*
Resposta: 
O período com a maior porcentagem da renda mensal para o pagamento de dívidas é em agosto/2026 com 28,99% da renda mensal comprometida.
Desde dezembro/2025, os valores apresentados foram os maiores da série.
Os menores valores aconteceram no início da série, entre março/2005 com 17% e julho/2005 com 17,71%
Entre março/2005 e agosto/2026, tivemos uma variação de +11,99 p.p.
*/

--Parte 2: Qual parte é juros e qual é amortização?

SELECT
    data_ref AS "Período",
    CAST(comprometimento_juros_estimado AS DECIMAL(5,2)) AS "Parte_Juros",
    CAST(comprometimento_amortizacao AS DECIMAL(5,2)) AS "Parte_Amortização"   
FROM vw_painel_mensal
WHERE comprometimento_juros_estimado IS NOT NULL
AND comprometimento_amortizacao IS NOT NULL
--ORDER BY Parte_Juros ASC
--ORDER BY Parte_Juros DESC
--ORDER BY Parte_Amortização ASC
--ORDER BY Parte_Amortização DESC

--juros p.p
SELECT 10.92 - 5.07

--amortização: ago/2026 x mar/2005
SELECT 18.07 - 11.93   -- +6,14 p.p.
--amortização: maior (mai/2024) x menor (mar/2005)
SELECT 18.29 - 11.93   -- +6,36 p.p.

--Comprometimento_total março/2005 = 17%
--Juros março/2005 = 5,07%
--Logo

SELECT (5.07 / 17.0000) * 100
--29,82% 

--Comprometimento_total agosto/2026 = 28,99%
--Juros agosto/2026 = 10,92%
--Logo

SELECT (10.92 / 28.99) * 100 
--37,67%

SELECT 37.67 - 29.82
--+7,85

/*
Resposta:
* Juros:
Os últimos 17 meses (abril/2025 até agosto/2026) foram os meses recordes onde a porcentagem da renda mensal das famílias foram para o pagamento de 
juros, sendo:
Agosto/2026 - 10,92%, Julho/2026 - 10,86% e Junho/2026 - 10,79% o top 3.

Os menores valores aconteceram em:
Março/2005 - 5,07%, Abril/2005 -5,11% e Maio/2005 - 5,19%

Aumento de 5,85 p.p entre Agosto/2026 e Março/2005 

* Amortização:
Para amortização das dívidas, os 5 maiores meses foram:
Maio/2024 - 18,29%, Janeiro/2023 - 18,24%, Fevereiro/2023 - 18,22%, Dezembro/2022 - 18,22% e Abril/2023 - 18,20%

Os menores valores aconteceram em:
Março/2005 - 11,93%, Abril/2005 - 12,09%, Maio/2005 - 12,23%

Aumento de 6,14 p.p entre Agosto/2026 e Março/2005. Entre os maior valor, Maio/2024 e o menor, Março/2005, tivemos um aumento de 6,36 p.p.

Em mar/2005, 29,82% da prestação ia para juros; em ago/2026 são 37,67% (+7,85 p.p.). 
Ou seja, uma parte maior do que as famílias pagam fica com o banco, e uma parte menor abate a dívida (a amortização caiu de 70,18% para 62,33% da prestação).
*/

-- =========================================================
-- P4 — Houve períodos em que o endividamento caiu, mas o comprometimento de renda subiu? Isso indica crédito mais caro.
-- =========================================================

-- Query

WITH variacao AS (
    SELECT
        atual.data_ref,
        atual.endividamento_total - ano_antes.endividamento_total AS var_endividamento_pp,
        atual.comprometimento_total - ano_antes.comprometimento_total AS var_comprometimento_pp
    FROM dbo.vw_painel_mensal atual
    JOIN dbo.vw_painel_mensal ano_antes
        ON ano_antes.data_ref = DATEADD(MONTH, -12, atual.data_ref)
)

SELECT data_ref, var_endividamento_pp, var_comprometimento_pp
FROM variacao
WHERE var_endividamento_pp < 0
    AND var_comprometimento_pp > 0
ORDER BY data_ref


/*
Resposta:
- Sim, houve um episódio claro: de dez/2022 a jul/2023 (8 meses seguidos), o endividamento foi menor que 12 meses antes
  (até −1,83 p.p.) e, ao mesmo tempo, o comprometimento de renda foi maior (até +2,51 p.p.).
- Ou seja, as famílias deviam menos, mas pagavam mais por mês: um padrão compatível com crédito mais caro ou prazos mais curtos.
- O episódio começa logo após o pico do endividamento em jul/2022.
- Fora dele, só 3 meses isolados (mai/2014, ago/2014 e dez/2016), com quedas muito pequenas na dívida.
*/
