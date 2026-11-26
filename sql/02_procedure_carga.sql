USE EndividamentoBR;
GO

CREATE OR ALTER PROCEDURE dbo.sp_carregar_indicadores
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    -- 1. Limpa o modelo (fato primeiro, por causa da chave estrangeira)
    DELETE FROM dbo.fato_indicador;
    DELETE FROM dbo.dim_calendario;

    -- 2. Calendário
    INSERT INTO dbo.dim_calendario (data_ref, ano, mes, nome_mes, ano_mes, trimestre)
    SELECT CAST(data_ref AS DATE), ano, mes, nome_mes, ano_mes, trimestre
    FROM stg.calendario;

    -- 3. Fato: só entram séries cadastradas e meses do calendário
    INSERT INTO dbo.fato_indicador (data_ref, cod_serie, valor)
    SELECT CAST(s.data_ref AS DATE), s.cod_serie, s.valor
    FROM stg.serie_valor s
    JOIN dbo.dim_serie      d ON d.cod_serie = s.cod_serie
    JOIN dbo.dim_calendario c ON c.data_ref  = CAST(s.data_ref AS DATE);

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER VIEW dbo.vw_painel_mensal
AS
SELECT
    f.data_ref,
    MAX(CASE WHEN f.cod_serie = 29037 THEN f.valor END) AS endividamento_total,
    MAX(CASE WHEN f.cod_serie = 29038 THEN f.valor END) AS endividamento_sem_habitacional,
    MAX(CASE WHEN f.cod_serie = 29034 THEN f.valor END) AS comprometimento_total,
    MAX(CASE WHEN f.cod_serie = 29035 THEN f.valor END) AS comprometimento_sem_habitacional,
    MAX(CASE WHEN f.cod_serie = 29036 THEN f.valor END) AS comprometimento_amortizacao,
    -- Juros não têm série própria: estimativa = total - amortização
    MAX(CASE WHEN f.cod_serie = 29034 THEN f.valor END)
      - MAX(CASE WHEN f.cod_serie = 29036 THEN f.valor END) AS comprometimento_juros_estimado,
    MAX(CASE WHEN f.cod_serie = 21084 THEN f.valor END) AS inadimplencia_pf,
    MAX(CASE WHEN f.cod_serie = 4189  THEN f.valor END) AS selic_mensal,
    MAX(CASE WHEN f.cod_serie = 13522 THEN f.valor END) AS ipca_12m
FROM dbo.fato_indicador f
GROUP BY f.data_ref;
GO

-- View para o Power BI: variação em 12 meses (P4), mais simples em SQL do que em DAX.
CREATE OR ALTER VIEW dbo.vw_variacao_12m AS
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
FROM variacao;
GO

SELECT TOP 20 *
FROM dbo.vw_variacao_12m
ORDER BY data_ref;