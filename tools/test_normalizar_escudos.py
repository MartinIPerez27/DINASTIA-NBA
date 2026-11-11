import unittest

from normalizar_escudos import normalizar


class NormalizarTest(unittest.TestCase):
    def test_clases_a_atributos(self):
        svg = '<svg><style type="text/css">.st0{fill:#CD1F43;}\n.st1,.st2{fill:#FFF;stroke:#000}</style>' \
              '<path class="st0" d="M0"/><path class="st1 st0" d="M1"/></svg>'
        salida = normalizar(svg)
        self.assertNotIn("<style", salida)
        self.assertIn('<path fill="#CD1F43" d="M0"/>', salida)
        self.assertIn('<path fill="#CD1F43" stroke="#000" d="M1"/>', salida)


if __name__ == "__main__":
    unittest.main()
