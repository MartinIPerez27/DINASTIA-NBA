"""Tests sin red del cálculo de cartas. Ejecutar: python -m unittest discover tools"""

import unittest

import extraer_cartas as ec

CLE, LAL, CHI, WAS, SAS = 1610612739, 1610612747, 1610612741, 1610612764, 1610612759


def temporada(season, team, gp=75, gs=None, minutos=36.0, pts=25.0, reb=7.0, oreb=1.0, ast=7.0,
              stl=1.5, blk=0.7, tov=3.5, fga=19.0, fgm=9.5, fg3a=4.0, fg3m=1.4, fta=7.0, ftm=5.2):
    """Una fila de SeasonTotalsRegularSeason a partir de promedios por partido."""
    por_partido = dict(MIN=minutos, PTS=pts, REB=reb, OREB=oreb, DREB=reb - oreb, AST=ast, STL=stl, BLK=blk,
                       TOV=tov, FGA=fga, FGM=fgm, FG3A=fg3a, FG3M=fg3m, FTA=fta, FTM=ftm)
    fila = {k: round(v * gp) for k, v in por_partido.items()}
    fila.update(SEASON_ID=season, TEAM_ID=team, GP=gp, GS=gp if gs is None else gs)
    return fila


def premio(desc, season, all_nba=None):
    return {"DESCRIPTION": desc, "SEASON": season, "ALL_NBA_TEAM_NUMBER": all_nba}


LEBRON_INFO = {"PERSON_ID": 2544, "DISPLAY_FIRST_LAST": "LeBron James", "POSITION": "Forward", "JERSEY": "23"}
LEBRON_CARRERA = [
    *[temporada(s, CLE, ast=7.4) for s in ("2014-15", "2015-16", "2016-17", "2017-18")],
    *[temporada(s, LAL, minutos=34.5, pts=26.0, ast=9.0, fg3a=5.5) for s in ("2019-20", "2020-21", "2021-22")],
]
LEBRON_PREMIOS = [
    premio("NBA Finals Most Valuable Player", "2015-16"),
    *[premio("All-NBA", s, "1") for s in ("2014-15", "2015-16", "2016-17", "2017-18")],
    premio("All-NBA", "2019-20", "1"),
    premio("NBA All-Star", "2020-21"),
]


class CartasTest(unittest.TestCase):
    def cartas_lebron(self):
        return {c["id"]: c for c in ec.cartas_de_jugador(LEBRON_INFO, LEBRON_CARRERA, LEBRON_PREMIOS)}

    def test_epocas_por_anio_de_cierre(self):
        self.assertEqual(ec.epoca_de("1989-90"), "anios90")
        self.assertEqual(ec.epoca_de("2009-10"), "anios2010")
        self.assertEqual(ec.epoca_de("2019-20"), "actualidad")
        self.assertIsNone(ec.epoca_de("1975-76"))

    def test_una_carta_por_franquicia_y_epoca_con_stats_propias(self):
        cartas = self.cartas_lebron()
        self.assertEqual(set(cartas), {"2544-CLE-10", "2544-LAL-act"})
        self.assertEqual(cartas["2544-CLE-10"]["stats"]["app"], 7.4)
        self.assertEqual(cartas["2544-LAL-act"]["stats"]["app"], 9.0)

    def test_posiciones_cambian_con_la_epoca(self):
        cartas = self.cartas_lebron()
        self.assertNotIn("BASE", cartas["2544-CLE-10"]["posiciones"])
        self.assertIn("BASE", cartas["2544-LAL-act"]["posiciones"])
        self.assertEqual(cartas["2544-CLE-10"]["rol"], "controladorTotal")

    def test_tier_segun_premios_del_tramo(self):
        cartas = self.cartas_lebron()
        self.assertEqual(cartas["2544-CLE-10"]["tier"], "sPlus")  # FMVP + 4x 1er equipo = 28
        self.assertEqual(cartas["2544-LAL-act"]["tier"], "a")  # 1er equipo + All-Star = 6

    def test_premio_de_temporada_con_traspaso_va_al_equipo_principal(self):
        carrera = [temporada("2001-02", WAS, gp=20, pts=10), temporada("2001-02", CHI, gp=60),
                   temporada("2002-03", CHI, gp=82)]
        _, principal = ec.agrupar(carrera)
        puntos, _ = ec.premios_por_grupo([premio("NBA Most Valuable Player", "2001-02")], principal)
        self.assertEqual(puntos[("CHI", "anios2000")], 10)
        self.assertEqual(puntos[("WAS", "anios2000")], 0)

    def test_sin_premios_o_pocos_partidos_no_hay_carta(self):
        info = {**LEBRON_INFO, "PERSON_ID": 1}
        self.assertEqual(ec.cartas_de_jugador(info, LEBRON_CARRERA, []), [])
        corta = [temporada("2015-16", CLE, gp=40)]
        self.assertEqual(ec.cartas_de_jugador(info, corta, [premio("NBA All-Star", "2015-16")]), [])

    def test_sexto_hombre_del_anio_define_el_rol(self):
        info = {"PERSON_ID": 1938, "DISPLAY_FIRST_LAST": "Manu Ginobili", "POSITION": "Guard", "JERSEY": "20"}
        carrera = [temporada(s, SAS, gs=20, minutos=28, pts=16, ast=4.0, fg3a=5) for s in ("2006-07", "2007-08")]
        carta = ec.cartas_de_jugador(info, carrera, [premio("NBA Sixth Man of the Year", "2007-08")])[0]
        self.assertEqual(carta["rol"], "directorSegundaUnidad")  # como en el GDD
        self.assertEqual(carta["posiciones"][0], "ESCOLTA")  # poco pase: escolta antes que base

    def test_iq_entre_60_y_99_y_ajustes_manuales(self):
        cartas = ec.cartas_de_jugador(LEBRON_INFO, LEBRON_CARRERA, LEBRON_PREMIOS)
        ec.asignar_iq(cartas)
        for c in cartas:
            self.assertTrue(60 <= c["stats"]["iq"] <= 99)
        ec.aplicar_ajustes(cartas, {"_ayuda": "x", "2544-LAL-act": {"dorsal": 6, "iq": 97},
                                    "2544-CLE-10": {"excluir": True}})
        self.assertEqual([(c["id"], c["dorsal"], c["stats"]["iq"]) for c in cartas], [("2544-LAL-act", 6, 97)])

    def test_dorsal(self):
        self.assertEqual(ec.dorsal_de("23"), 23)
        self.assertEqual(ec.dorsal_de("8-24"), 8)
        self.assertEqual(ec.dorsal_de(""), 0)


class CatalogoTest(unittest.TestCase):
    """Cada carta del catálogo empaquetado usa el ID oficial de ese jugador (evita fotos cruzadas)."""

    def test_ids_coinciden_con_el_nombre(self):
        try:
            from nba_api.stats.static import players
        except ImportError:
            self.skipTest("nba_api no instalado")
        import json
        import unicodedata

        def normalizar(s):
            return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()

        for carta in json.loads(ec.SALIDA.read_text(encoding="utf-8")):
            oficial = players.find_player_by_id(carta["nbaPlayerId"])
            self.assertIsNotNone(oficial, carta["id"])
            self.assertEqual(normalizar(oficial["full_name"]), normalizar(carta["nombre"]), carta["id"])


if __name__ == "__main__":
    unittest.main()
