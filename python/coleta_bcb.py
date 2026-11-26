"""
coleta_bcb.py
Baixa séries do SGS (Banco Central do Brasil) e carrega no SQL Server.
Uso: python coleta_bcb.py
"""
import time
from datetime import date

import pandas as pd
import requests
from sqlalchemy import create_engine, text

# ---------------------------------------------------------------------------
# 1. Configurações
# ---------------------------------------------------------------------------
SERIES = {
    29037: "endividamento_total",
    29038: "endividamento_sem_habitacional",
    29034: "comprometimento_total",
    29035: "comprometimento_sem_habitacional",
    29036: "comprometimento_amortizacao",
    21084: "inadimplencia_pf",
    4189: "selic_mensal",
    13522: "ipca_12m",
}

ANO_INICIAL = 2005
ANOS_POR_JANELA = 5
URL = "https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo}/dados"

CONEXAO = (
    "mssql+pyodbc://@localhost\\MSSQLSERVER01/EndividamentoBR"
    "?driver=ODBC+Driver+18+for+SQL+Server"
    "&trusted_connection=yes"
    "&TrustServerCertificate=yes"
)

MESES = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
         "Jul", "Ago", "Set", "Out", "Nov", "Dez"]


# ---------------------------------------------------------------------------
# 2. Coleta
# ---------------------------------------------------------------------------
def janelas(ano_inicial, hoje, anos_por_janela):
    """Gera pares (data_inicial, data_final) em blocos de N anos até hoje."""
    for ano in range(ano_inicial, hoje.year + 1, anos_por_janela):
        inicio = date(ano, 1, 1)
        fim = min(date(ano + anos_por_janela - 1, 12, 31), hoje)
        yield inicio, fim


def baixar_serie(codigo):
    """Baixa uma série inteira do SGS, janela por janela."""
    registros = []
    for inicio, fim in janelas(ANO_INICIAL, date.today(), ANOS_POR_JANELA):
        params = {
            "formato": "json",
            "dataInicial": inicio.strftime("%d/%m/%Y"),
            "dataFinal": fim.strftime("%d/%m/%Y"),
        }
        resposta = requests.get(URL.format(codigo=codigo), params=params, timeout=60)

        # Janela sem dados (ex.: série que começa depois de 2005) -> pula
        if resposta.status_code == 404:
            continue
        resposta.raise_for_status()  # qualquer outro erro interrompe o script

        registros.extend(resposta.json())
        time.sleep(0.5)  # gentileza com o servidor do BCB

    df = pd.DataFrame(registros, columns=["data", "valor"])
    df["cod_serie"] = codigo
    return df


# ---------------------------------------------------------------------------
# 3. Tratamento
# ---------------------------------------------------------------------------
def tratar(df):
    """Converte tipos e remove duplicatas entre janelas."""
    df = df.rename(columns={"data": "data_ref"})
    df["data_ref"] = pd.to_datetime(df["data_ref"], format="%d/%m/%Y")
    df["valor"] = pd.to_numeric(df["valor"], errors="coerce")
    df = df.drop_duplicates(subset=["cod_serie", "data_ref"])
    return df[["cod_serie", "data_ref", "valor"]]


def gerar_calendario(ano_inicial, hoje):
    """Uma linha por mês (dia 01), de janeiro do ano inicial até o mês atual."""
    datas = pd.date_range(f"{ano_inicial}-01-01", hoje, freq="MS")
    return pd.DataFrame({
        "data_ref": datas,
        "ano": datas.year,
        "mes": datas.month,
        "nome_mes": [MESES[m - 1] for m in datas.month],
        "ano_mes": datas.strftime("%Y-%m"),
        "trimestre": datas.quarter,
    })


# ---------------------------------------------------------------------------
# 4. Execução
# ---------------------------------------------------------------------------
def main():
    partes = []
    for codigo, nome in SERIES.items():
        print(f"Baixando {codigo} ({nome})...")
        df = tratar(baixar_serie(codigo))
        print(f"   {len(df)} meses, de {df['data_ref'].min():%m/%Y} a {df['data_ref'].max():%m/%Y}")
        partes.append(df)

    dados = pd.concat(partes, ignore_index=True)
    calendario = gerar_calendario(ANO_INICIAL, date.today())

    engine = create_engine(CONEXAO)
    with engine.begin() as con:  # uma transação: tudo ou nada
        dados.to_sql("serie_valor", con, schema="stg", if_exists="replace", index=False)
        calendario.to_sql("calendario", con, schema="stg", if_exists="replace", index=False)
        con.execute(text("EXEC dbo.sp_carregar_indicadores"))

    print(f"Carga concluída: {len(dados)} linhas em stg.serie_valor.")


if __name__ == "__main__":
    main()