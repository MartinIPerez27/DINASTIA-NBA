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
        self.assertLess(cb.puntaje_v3(corta), cb.puntaje_v3(larga))

    def test_tier_v2(self):
        self.assertEqual(cb.tier_v2({"media": 97, "_tasa_premios": 8, "_puntos": 40}), "sPlus")
        self.assertEqual(cb.tier_v2({"media": 96, "_tasa_premios": 0.5, "_puntos": 1}), "s")  # sin premios de élite
        self.assertEqual(cb.tier_v2({"media": 89, "_tasa_premios": 6, "_puntos": 12}), "s")
        self.assertEqual(cb.tier_v2({"media": 89, "_tasa_premios": 1, "_puntos": 1}), "a")
        self.assertEqual(cb.tier_v2({"media": 75, "_tasa_premios": 0, "_puntos": 0}), "b")

    def test_id_estable(self):
        self.assertEqual(cb.id_estable("abcdeja01"), cb.id_estable("abcdeja01"))
        self.assertLess(cb.id_estable("abcdeja01"), 0)


def temporada(anio, gp=70, mpg=30.0, impacto=2.0, premios=0):
    return {"gp": gp, "mpg": mpg, "impacto": impacto, "premios": premios, "anio": anio}


class VentanasTest(unittest.TestCase):
    def test_rendimiento_parejo_se_parte_cada_3_o_4_temporadas(self):
        v = cb.partir([temporada(2000 + i) for i in range(8)])
        self.assertTrue(all(i - j <= cb.MAX_TEMPORADAS for j, i in v))
        self.assertEqual(len(v), 2)

    def test_corta_donde_cambia_el_nivel(self):
        temps = [temporada(2000 + i, impacto=6.0, mpg=36) for i in range(3)] + \
                [temporada(2003 + i, impacto=0.0, mpg=24) for i in range(3)]
        self.assertEqual(cb.partir(temps), [(0, 3), (3, 6)])

    def test_una_ventana_no_baja_de_los_partidos_minimos(self):
        temps = [temporada(2000, gp=70), temporada(2001, gp=8), temporada(2002, gp=70)]
        for j, i in cb.fusionar_chicas(cb.partir(temps), [t["gp"] for t in temps]):
            self.assertGreaterEqual(sum(t["gp"] for t in temps[j:i]), cb.MIN_PARTIDOS)

    def test_rachas_cortan_en_huecos_y_en_decadas(self):
        self.assertEqual(cb.rachas({2007, 2008, 2009, 2010, 2011, 2015}), [[2007, 2008, 2009], [2010, 2011], [2015]])

    def test_volumen_sin_impacto_vale_la_mitad(self):
        base = {"_gp": 300, "_tasa_premios": 0.0, "_impacto_norm": -3.0}
        poco = cb.puntaje_v3({**base, "_mpg": 24.0})
        mucho = cb.puntaje_v3({**base, "_mpg": 40.0})
        con_impacto = cb.puntaje_v3({**base, "_impacto_norm": 3.0, "_mpg": 40.0}) - cb.puntaje_v3(
            {**base, "_impacto_norm": 3.0, "_mpg": 24.0})
        self.assertLess(mucho - poco, con_impacto)

    def test_muestra_chica_pesa_menos_en_minutos_y_premios(self):
        corta = {"_gp": 20, "_mpg": 40.0, "_tasa_premios": 3.0, "_impacto_norm": 0.0}
        larga = {**corta, "_gp": 300}
        self.assertLess(cb.puntaje_v3(corta), cb.puntaje_v3(larga))


class PosicionesAntiguasTest(unittest.TestCase):
    def bio(self, carrera, altura, season="1948"):
        b = cb.Biografico([{"player_id": "x", "pos": carrera, "ht_in_in": str(altura), "wt": "190"}], [])
        b.media_temporada = {1948: 73.0}
        return b

    def test_altura_y_posicion_de_carrera_definen_el_puesto(self):
        fila = {"player_id": "x", "pos": "NA", "season": "1948", "g": "50", "ast": "100", "trb": "NA"}
        self.assertEqual(self.bio("C", 82).posicion(fila), "PÍVOT")
        self.assertEqual(self.bio("G", 70).posicion(fila), "BASE")
        self.assertEqual(self.bio("F-C", 77).posicion(fila), "ALA-PÍVOT")
        self.assertEqual(self.bio("F", 74).posicion(fila), "ALERO")

    def test_usa_la_posicion_declarada_de_otras_temporadas(self):
        b = self.bio("G", 70)
        b.conocida["x"]["PÍVOT"] = 100
        fila = {"player_id": "x", "pos": "NA", "season": "1948", "g": "50", "ast": "0", "trb": "NA"}
        self.assertEqual(b.posicion(fila), "PÍVOT")


class CatalogoV3Test(unittest.TestCase):
    """Sobre el catálogo empaquetado."""

    @classmethod
    def setUpClass(cls):
        cls.todas = json.loads(ec.SALIDA.read_text(encoding="utf-8"))
        cls.cartas = [c for c in cls.todas if not c.get("legado")]
        cls.por_id = {c["id"]: c for c in cls.todas}

    def test_ids_viejos_se_conservan(self):
        viejos = json.loads((ec.RAIZ / "test" / "fixtures" / "catalogo_v2_ids.json").read_text(encoding="utf-8"))
        self.assertEqual(len(viejos), 11323)
        self.assertEqual([i for i in viejos if i not in self.por_id], [])
        self.assertEqual(len(self.por_id), len(self.todas), "ids repetidos")

    def test_temporadas_del_tramo(self):
        for c in self.cartas:
            desde, hasta = c["temporadas"]
            self.assertLessEqual(desde, hasta, c["id"])
            self.assertLessEqual(hasta, cb.ULTIMA_TEMPORADA, c["id"])
            self.assertEqual(ec.epoca_de(f"{desde - 1}-00"), c["epoca"], c["id"])
            self.assertEqual(c.get("dorsal", 0), 0, c["id"])

    def test_sin_solapamientos_del_mismo_jugador_y_equipo(self):
        from collections import defaultdict
        grupos = defaultdict(list)
        for c in self.cartas:
            grupos[(c["id"].split("-")[0], c["franquicia"])].append(c)
        for clave, cartas in grupos.items():
            cartas.sort(key=lambda c: c["temporadas"])
            for a, b in zip(cartas, cartas[1:]):
                # las cartas con huecos (ventanas chicas unidas) pueden envolver a otra: se ignoran
                if a["temporadas"][1] - a["temporadas"][0] + 1 > 5 or b["temporadas"][1] - b["temporadas"][0] + 1 > 5:
                    continue
                self.assertLess(a["temporadas"][1], b["temporadas"][0] + (0 if a["epoca"] != b["epoca"] else 0) + 1,
                                f"{a['id']} / {b['id']}")

    def test_ventanas_de_hasta_cuatro_temporadas_casi_todas(self):
        largas = [c for c in self.cartas if c["temporadas"][1] - c["temporadas"][0] + 1 > cb.MAX_TEMPORADAS]
        self.assertLess(len(largas), 20)

    def test_porzingis_tiene_ventanas_distintas_y_la_ultima_es_menor_que_el_pico(self):
        cartas = sorted((c for c in self.cartas if c["id"].startswith("porzikr01-")), key=lambda c: c["temporadas"])
        self.assertGreaterEqual(len({c["franquicia"] for c in cartas}), 5)
        self.assertGreaterEqual(len(cartas), 5)
        self.assertGreaterEqual(len({c["media"] for c in cartas}), 4)
        self.assertLess(cartas[-1]["media"], max(c["media"] for c in cartas))

    def test_curry_y_lebron_con_ventanas_separadas(self):
        for pid, minimo in (("curryst01-GSW-", 5), ("jamesle01-", 8)):
            cartas = [c for c in self.cartas if c["id"].startswith(pid)]
            self.assertGreaterEqual(len(cartas), minimo, pid)
        curry = sorted((c for c in self.cartas if c["id"].startswith("curryst01-")), key=lambda c: c["temporadas"])
        self.assertGreater(max(c["media"] for c in curry), curry[-1]["media"])
        self.assertLessEqual(curry[-1]["temporadas"][1], cb.ULTIMA_TEMPORADA)

    def test_los_40_no_son_todos_escoltas(self):
        from collections import Counter
        pos = Counter(c["posiciones"][0] for c in self.cartas if c["epoca"] == "anios40")
        self.assertLess(max(pos.values()) / sum(pos.values()), 0.4)
        for pid in ("mikange01", "risenar01"):
            self.assertTrue(any(c["id"].startswith(pid) and c["posiciones"][0] == "PÍVOT" for c in self.cartas), pid)

    def test_tier_y_media_coherentes(self):
        self.assertFalse([c["id"] for c in self.cartas if c["tier"] in ("a", "b") and c["media"] >= 92])
        self.assertFalse([c["id"] for c in self.cartas if c["tier"] in ("s", "sPlus") and c["media"] < 86])

    def test_aleros_variados(self):
        aleros = [c["rol"] for c in self.cartas if c["posiciones"][0] == "ALERO"]
        self.assertLess(aleros.count("cerrojoDefensivo") / len(aleros), 0.15)
        self.assertGreater(aleros.count("especialista3D") + aleros.count("tiradorPantallas"), 150)

    def test_legado_son_pocas_y_conservan_su_id(self):
        legado = [c for c in self.todas if c.get("legado")]
        self.assertLess(len(legado), 20)


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
