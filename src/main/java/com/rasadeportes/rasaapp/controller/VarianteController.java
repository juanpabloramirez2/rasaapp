package com.rasadeportes.rasaapp.controller;

import com.rasadeportes.rasaapp.model.Producto;
import com.rasadeportes.rasaapp.model.Variante;
import com.rasadeportes.rasaapp.services.ProductoService;
import com.rasadeportes.rasaapp.services.VarianteService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

@Controller
@RequestMapping("/dashboard/variantes")
public class VarianteController {

    private final VarianteService varianteService;
    private final ProductoService productoService;


    public VarianteController(VarianteService varianteService, ProductoService productoService) {
        this.varianteService = varianteService;
        this.productoService = productoService;
    }

    @GetMapping("/producto/{productoId}")
    public String listarVariantes(@PathVariable Long productoId, Model model) {

        Producto producto = productoService.obtenerProducto(productoId);

        model.addAttribute("variantes", varianteService.obtenerPorProducto(productoId));
        model.addAttribute("producto", producto);
        model.addAttribute("productoId", productoId);
        return "variantes/listado";
    }

    @GetMapping("/nueva/{productoId}")
    public String nuevaVariante(@PathVariable Long productoId, Model model) {
        Producto producto = productoService.obtenerProducto(productoId);

        model.addAttribute("producto", producto);
        model.addAttribute("variante", new Variante());
        model.addAttribute("productoId", productoId);
        return "variantes/formulario";
    }

    @PostMapping("/guardar/{productoId}")
    public String guardarVariante(@PathVariable Long productoId,
                                  @ModelAttribute Variante variante) {
        varianteService.guardarVariante(productoId, variante);
        return "redirect:/dashboard/variantes/producto/" + productoId;
    }

    @GetMapping("/editar/{id}")
    public String editarVariante(@PathVariable Long id, Model model) {
        Variante variante = varianteService.obtenerVariante(id);

        model.addAttribute("producto", variante.getProducto());
        model.addAttribute("variante", variante);
        model.addAttribute("productoId", variante.getProducto().getId());
        return "variantes/formulario";
    }

    @GetMapping("/eliminar/{id}")
    public String eliminarVariante(@PathVariable Long id) {
        Long productoId = varianteService.obtenerProductoIdPorVarianteId(id);
        varianteService.eliminarVariante(id);
        return "redirect:/dashboard/variantes/producto/" + productoId;
    }
}