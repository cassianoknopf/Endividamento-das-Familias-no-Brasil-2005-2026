/* 
Validação de dados: Verificando a existência de valores nulos ou buracos entre os períodos pesquisados.
Meses carregados e meses esperados com valores iguais
*/
SELECT
    d.cod_serie,
    d.nome_coluna,
    MIN(f.data_ref)                                     AS primeiro_mes,
    MAX(f.data_ref)                                     AS ultimo_mes,
    COUNT(*)                                            AS meses_carregados,
    DATEDIFF(MONTH, MIN(f.data_ref), MAX(f.data_ref)) + 1 AS meses_esperados,
    DATEDIFF(MONTH, MIN(f.data_ref), MAX(f.data_ref)) + 1 - COUNT(*) AS buracos,
    COUNT(*) - COUNT(f.valor)                           AS valores_nulos,
    MIN(f.valor)                                        AS menor_valor,
    MAX(f.valor)                                        AS maior_valor
FROM dbo.fato_indicador f
JOIN dbo.dim_serie d ON d.cod_serie = f.cod_serie
GROUP BY d.cod_serie, d.nome_coluna
ORDER BY d.cod_serie

/* 
O maior valor da série de endividamento em todo o período (50,11%) é justamente o último mês, 08/2026. 
Ou seja, as famílias brasileiras estão no maior nível de endividamento da série histórica, 
iniciada em 2005
*/


/*
Validando informações com a fonte (site)
https://api.bcb.gov.br/dados/serie/bcdata.sgs.29037/dados/ultimos/12?formato=json
Verificado em 10/11/2026 que os 3 últimos valores batem com a API.
*/
SELECT TOP 3 data_ref, valor
FROM dbo.fato_indicador
WHERE cod_serie = 29037
ORDER BY data_ref DESC

/*
Resultado esperado = 0
O endividamento total sempre vai incluir o habitacional. 
Com isso, o valor NUNCA poderá ser menor que o endividamento sem habitacional.
*/
SELECT COUNT(*) AS meses_inconsistentes
FROM dbo.vw_painel_mensal
WHERE endividamento_total < endividamento_sem_habitacional;

/*
Resultado esperado = nenhuma linha
O comprometimento total inclui o crédito habitacional.
Logo, NUNCA pode ser menor que o comprometimento sem habitacional.
*/
SELECT
    data_ref,
    comprometimento_total,
    comprometimento_sem_habitacional,
    comprometimento_total - comprometimento_sem_habitacional AS diferenca_pp
FROM dbo.vw_painel_mensal
WHERE comprometimento_total < comprometimento_sem_habitacional
ORDER BY data_ref;