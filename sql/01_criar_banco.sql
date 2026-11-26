CREATE DATABASE EndividamentoBR;
GO
USE EndividamentoBR;
GO
CREATE SCHEMA stg; -- Área de staging: dados brutos da API, recriados a cada carga
GO

CREATE TABLE dbo.dim_serie (
    cod_serie    INT            NOT NULL PRIMARY KEY,
    nome_coluna  VARCHAR(50)    NOT NULL,
    descricao    NVARCHAR(200)  NOT NULL,
    unidade      VARCHAR(10)    NOT NULL,
    grupo        NVARCHAR(30)   NOT NULL
);

CREATE TABLE dbo.dim_calendario (
    data_ref   DATE        NOT NULL PRIMARY KEY,
    ano        INT         NOT NULL,
    mes        INT         NOT NULL,
    nome_mes   VARCHAR(3)  NOT NULL,
    ano_mes    CHAR(7)     NOT NULL,   -- '2024-03'
    trimestre  INT         NOT NULL
);

CREATE TABLE dbo.fato_indicador (
    data_ref   DATE           NOT NULL REFERENCES dbo.dim_calendario (data_ref),
    cod_serie  INT            NOT NULL REFERENCES dbo.dim_serie (cod_serie),
    valor      DECIMAL(10,4)  NULL,
    CONSTRAINT pk_fato_indicador PRIMARY KEY (data_ref, cod_serie)
);

INSERT INTO dbo.dim_serie (cod_serie, nome_coluna, descricao, unidade, grupo) VALUES
 (29037, 'endividamento_total',            N'Endividamento das famílias com o SFN / renda 12 meses',            '%',      N'Endividamento'),
 (29038, 'endividamento_sem_habitacional', N'Endividamento das famílias exceto crédito habitacional',          '%',      N'Endividamento'),
 (29034, 'comprometimento_total',          N'Comprometimento de renda com serviço da dívida (c/ ajuste sazonal)', '%',      N'Comprometimento'),
 (29035, 'comprometimento_sem_habitacional', N'Comprometimento de renda exceto crédito habitacional (c/ ajuste sazonal)', '%',      N'Comprometimento'),
 (29036, 'comprometimento_amortizacao',    N'Comprometimento de renda com amortização (c/ ajuste sazonal)',     '%',      N'Comprometimento'),
 (21084, 'inadimplencia_pf',               N'Inadimplência da carteira de crédito PF (>90 dias)',              '%',      N'Inadimplência'),
 (4189,  'selic_mensal',                   N'Selic acumulada no mês anualizada base 252',                     '% a.a.', N'Juros e inflação'),
 (13522, 'ipca_12m',                       N'IPCA acumulado em 12 meses',                                     '%',      N'Juros e inflação');