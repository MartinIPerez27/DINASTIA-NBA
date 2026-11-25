import unittest

import novatos_2026 as n

HTML = """
<table id="rookies"><tbody>
<tr><th data-stat="ranker">1</th><td data-stat="player">A.J. Dybantsa</td><td data-stat="g">15</td><td data-stat="pts_per_g">16.7</td><td data-stat="trb_per_g">7.2</td><td data-stat="ast_per_g">3.1</td></tr>
<tr><th data-stat="ranker">2</th><td data-stat="player">Nikola Jokić</td><td data-stat="g">0</td><td data-stat="pts_per_g"></td><td data-stat="trb_per_g"></td><td data-stat="ast_per_g"></td></tr>
<tr class="thead"><th data-stat="ranker">Rk</th><th data-stat="player">Player</th></tr>
</tbody></table>
<table id="otra"><tr><td data-stat="player">Nadie</td><td data-stat="g">9</td></tr></table>
"""


class PruebasNovatos(unittest.TestCase):
    def test_normalizar_saca_tildes_y_puntos(self):
        self.assertEqual(n.normalizar("A.J. Dybantsa"), "aj dybantsa")
        self.assertEqual(n.normalizar("Nikola Jokić"), "nikola jokic")

    def test_parsear_solo_la_tabla_de_novatos_y_con_partidos(self):
        r = n.parsear(HTML)
        self.assertEqual(list(r), ["aj dybantsa"])
        self.assertEqual(r["aj dybantsa"], {"g": 15, "pts": 16.7, "reb": 7.2, "ast": 3.1})

    def test_combinar_agrega_y_quita_real(self):
        draft = [{"pick": 1, "nombre": "AJ Dybantsa"}, {"pick": 2, "nombre": "Otro", "real": {"g": 1}}]
        n.combinar(draft, n.parsear(HTML))
        self.assertEqual(draft[0]["real"]["g"], 15)
        self.assertNotIn("real", draft[1])


if __name__ == "__main__":
    unittest.main()
