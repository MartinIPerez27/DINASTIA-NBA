import unittest

import records_nba as r

CARRERA = """<table id="nba"><thead><tr><th>Rank</th><th>Player</th><th>PTS</th></tr></thead>
<tr><td>1.</td><td><strong><a href="/x">LeBron James</a></strong></td><td>43,672</td></tr>
<tr><td>2.</td><td><a href="/y">Kareem Abdul-Jabbar</a>*</td><td>38387</td></tr></table>
<table id="aba"><tr><td>x</td><td>Otro</td><td>1</td></tr></table>"""

TEMPORADA = """<table id="stats_NBA"><tr><th>Rank</th><th>Player</th><th>PPG</th><th>Season</th></tr>
<tr><td>1.</td><td><a>Wilt Chamberlain</a>*</td><td>50.36</td><td>1961-62</td></tr></table>"""

PARTIDO = """<table id="stats_game_pts"><tr><th>Rank</th><th>Player</th><th>PTS</th><th>Date</th><th>Tm</th></tr>
<tr><td>1.</td><td><a>Wilt Chamberlain</a>*</td><td>100</td><td>1962-03-02</td><td>PHW</td></tr></table>"""


WIKI = """<table><tr><th>Rebounds</th><th>Player</th><th>Date</th><th>Team</th></tr>
<tr><td>55</td><td>Wilt Chamberlain*</td><td>November 24, 1960</td><td>Philadelphia Warriors</td></tr>
<tr><td>51</td><td>Bill Russell*</td><td>February 5, 1960</td><td>Boston Celtics</td></tr>
<tr><td>49</td><td>Bill Russell* (2)</td><td>1957</td><td>Boston</td></tr>
<tr><td>Dikembe Mutombo</td><td>Date x</td><td>Equipo</td></tr>
<tr><td>November 16, 1962</td><td>4</td><td>San Francisco</td></tr>
<tr><td>9</td><td>x</td><td>x</td><td>x</td></tr><tr><td>8</td><td>x</td><td>x</td><td>x</td></tr>
<tr><td>7</td><td>x</td><td>x</td><td>x</td></tr><tr><td>6</td><td>x</td><td>x</td><td>x</td></tr>
<tr><td>5</td><td>x</td><td>x</td><td>x</td></tr><tr><td>4</td><td>x</td><td>x</td><td>x</td></tr></table>"""


class RecordsNba(unittest.TestCase):
    def test_wikipedia_limpia_nombres_y_hereda_el_valor_de_celdas_combinadas(self):
        f = r.filas_partido_wiki(WIKI, "Rebounds")
        self.assertEqual((f[0]["nombre"], f[0]["valor"]), ("Wilt Chamberlain", 55))
        self.assertEqual(f[2]["nombre"], "Bill Russell")
        self.assertEqual(f[3]["valor"], 49, "la fila combinada hereda el valor")
        self.assertTrue(all(x["valor"] >= 4 and not any(c.isdigit() for c in x["nombre"]) for x in f), "sin filas desalineadas")


    def test_carrera_toma_solo_la_tabla_nba_y_marca_a_los_activos(self):
        f = r.filas_carrera(CARRERA)
        self.assertEqual([x["nombre"] for x in f], ["LeBron James", "Kareem Abdul-Jabbar"])
        self.assertEqual(f[0]["valor"], 43672)
        self.assertTrue(f[0]["activo"])
        self.assertFalse(f[1]["activo"])

    def test_temporada_y_partido(self):
        t = r.filas_temporada(TEMPORADA)
        self.assertEqual((t[0]["nombre"], t[0]["valor"], t[0]["temporada"]), ("Wilt Chamberlain", 50.36, "1961-62"))
        p = r.filas_partido(PARTIDO)
        self.assertEqual((p[0]["valor"], p[0]["fecha"], p[0]["equipo"]), (100, "1962-03-02", "PHW"))

    def test_sin_tabla_falla_fuerte(self):
        with self.assertRaises(ValueError):
            r.filas_carrera("<table id='otra'></table>")


if __name__ == "__main__":
    unittest.main()
