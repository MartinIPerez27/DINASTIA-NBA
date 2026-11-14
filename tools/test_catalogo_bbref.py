import json
import unittest

import catalogo_bbref as cb
import extraer_cartas as ec


def perfil(**kw):
    base = {"pts": 12.0, "reb": 5.0, "oreb": 1.0, "ast": 2.0, "stl": 1.0, "blk": 0.4, "tres": 0.2,
            "pct3": 0.33, "libres": 0.2, "dbpm": None}
    return {**base, **kw}


class RolesTest(unittest.TestCase):
    def test_alero_tirador_no_es_cerrojo(self):
        # Duncan Robinson: casi todos sus tiros son triples y los mete; poca defensa.
        self.assertEqual(ec.rol_de("ALERO", perfil(tres=0.75, pct3=0.40, stl=0.6, blk=0.3, dbpm=-1.5), False),
                         "tiradorPantallas")

    def test_alero_3d_y_cerrojo(self):
        self.assertEqual(ec.rol_de("ALERO", perfil(tres=0.45, pct3=0.38, stl=1.4, blk=0.6, dbpm=1.0), False),
                         "especialista3D")
        self.assertEqual(ec.rol_de("ALERO", perfil(stl=2.0, blk=1.0, dbpm=2.0), False), "cerrojoDefensivo")

    def test_alero_por_defecto_es_cortador(self):
        self.assertEqual(ec.rol_de("ALERO", perfil(), False), "aleroCortador")

    def test_sin_buen_impacto_defensivo_no_es_cerrojo(self):
        self.assertNotEqual(ec.rol_de("ALERO", perfil(stl=2.0, blk=1.0, dbpm=-0.5), False), "cerrojoDefensivo")


def carta(cid, epoca, impacto, gp=200, mpg=30.0, tasa=0.0, puntos=0):
    return {"id": cid, "epoca": epoca, "_impacto": impacto, "_gp": gp, "_mpg": mpg, "_tasa_premios": tasa,
            "_puntos": puntos, "_eficiencia": 10.0}


class MediaTest(unittest.TestCase):
    def test_mas_impacto_mas_media_y_respeta_la_escala_de_la_epoca(self):
        n = sum(cb.DISTRIBUCION_MEDIA["anios2010"].values())
        cartas = [carta(f"c{i:05d}", "anios2010", impacto=-6 + 12 * i / n) for i in range(n)]
        cb.asignar_media(cartas)
        medias = [c["media"] for c in cartas]
        self.assertEqual(medias, sorted(medias))
        from collections import Counter
        self.assertEqual(Counter(medias), Counter(cb.DISTRIBUCION_MEDIA["anios2010"]))

    def test_muestra_chica_se_acerca_al_promedio(self):
        corta = carta("a", "anios2010", impacto=8, gp=20)
        larga = carta("b", "anios2010", impacto=8, gp=500)
        cb.normalizar_impacto([corta, larga] + [carta(f"x{i}", "anios2010", i % 7 - 3) for i in range(50)])
        self.assertLess(cb.puntaje_v2(corta), cb.puntaje_v2(larga))

    def test_tier_v2(self):
        self.assertEqual(cb.tier_v2({"media": 97, "_tasa_premios": 8, "_puntos": 40}), "sPlus")
        self.assertEqual(cb.tier_v2({"media": 96, "_tasa_premios": 0.5, "_puntos": 1}), "s")  # sin premios de élite
        self.assertEqual(cb.tier_v2({"media": 89, "_tasa_premios": 6, "_puntos": 12}), "s")
        self.assertEqual(cb.tier_v2({"media": 89, "_tasa_premios": 1, "_puntos": 1}), "a")
        self.assertEqual(cb.tier_v2({"media": 75, "_tasa_premios": 0, "_puntos": 0}), "b")

    def test_id_estable(self):
        self.assertEqual(cb.id_estable("abcdeja01"), cb.id_estable("abcdeja01"))
        self.assertLess(cb.id_estable("abcdeja01"), 0)


class CatalogoV2Test(unittest.TestCase):
    """Sobre el catálogo empaquetado."""

    @classmethod
    def setUpClass(cls):
        cls.cartas = json.loads(ec.SALIDA.read_text(encoding="utf-8"))

    def test_temporadas_del_tramo(self):
        for c in self.cartas:
            desde, hasta = c["temporadas"]
            self.assertLessEqual(desde, hasta, c["id"])
            self.assertEqual(ec.epoca_de(f"{desde - 1}-00"), c["epoca"], c["id"])
        por_id = {c["id"]: c for c in self.cartas}
        self.assertEqual(por_id["lillada01-MIL-act"]["temporadas"], [2024, 2025])

    def test_tier_y_media_coherentes(self):
        self.assertFalse([c["id"] for c in self.cartas if c["tier"] in ("a", "b") and c["media"] >= 92])
        self.assertFalse([c["id"] for c in self.cartas if c["tier"] in ("s", "sPlus") and c["media"] < 86])

    def test_aleros_variados(self):
        aleros = [c["rol"] for c in self.cartas if c["posiciones"][0] == "ALERO"]
        self.assertLess(aleros.count("cerrojoDefensivo") / len(aleros), 0.15)
        self.assertGreater(aleros.count("especialista3D") + aleros.count("tiradorPantallas"), 150)


if __name__ == "__main__":
    unittest.main()


class BiografiasTest(unittest.TestCase):
    def test_draft_universidad_y_nacimiento(self):
        carreras = [
            {"player_id": "jordami01", "colleges": "UNC", "birth_date": "1963-02-17"},
            {"player_id": "nowitdi01", "colleges": "NA", "birth_date": "1978-06-19"},
            {"player_id": "traspa01", "colleges": "Weber State, Utah", "birth_date": "NA"},
        ]
        drafts = [
            {"season": "1984", "lg": "NBA", "overall_pick": "3", "player_id": "jordami01"},
            {"season": "1985", "lg": "NBA", "overall_pick": "77", "player_id": "sabonar01"},
            {"season": "1986", "lg": "NBA", "overall_pick": "24", "player_id": "sabonar01"},
            {"season": "1990", "lg": "NBA", "overall_pick": "NA", "player_id": "NA"},
        ]
        bio = cb.biografias(carreras, drafts)
        self.assertEqual(bio["jordami01"], {"draft": [1984, 3], "universidad": "North Carolina", "nacimiento": 1963})
        self.assertEqual(bio["nowitdi01"], {"draft": None, "universidad": None, "nacimiento": 1978})
        self.assertEqual(bio["traspa01"]["universidad"], "Utah")  # la de egreso
        self.assertIsNone(bio["traspa01"]["nacimiento"])
        self.assertEqual(bio["sabonar01"]["draft"], [1986, 24])  # el último draft en el que lo eligieron


class UniversidadesTest(unittest.TestCase):
    def test_nombres_canonicos(self):
        self.assertEqual(cb.universidad_canonica("UNC"), "North Carolina")
        self.assertEqual(cb.universidad_canonica("UConn"), "Connecticut")
        self.assertEqual(cb.universidad_canonica("Ball State University"), "Ball State")
        self.assertEqual(cb.universidad_canonica("University of Dayton"), "Dayton")
        self.assertEqual(cb.universidad_canonica("California University of Pennslyvania"),
                         "California University of Pennsylvania")
        self.assertEqual(cb.universidad_canonica("  Duke "), "Duke")
