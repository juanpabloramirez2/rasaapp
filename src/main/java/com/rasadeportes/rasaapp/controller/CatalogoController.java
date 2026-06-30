package com.rasadeportes.rasaapp.controller;

import com.rasadeportes.rasaapp.model.Producto;
import com.rasadeportes.rasaapp.model.Categoria;
import com.rasadeportes.rasaapp.services.ProductoService;
import com.rasadeportes.rasaapp.services.CategoriaService;
import com.rasadeportes.rasaapp.services.VarianteService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Controller
@RequestMapping("/catalogo")
public class CatalogoController {

    private final ProductoService productoService;
    private final CategoriaService categoriaService;
    private final VarianteService varianteService;

    public CatalogoController(ProductoService productoService, CategoriaService categoriaService, VarianteService varianteService) {
        this.productoService = productoService;
        this.categoriaService = categoriaService;
        this.varianteService = varianteService;
    }

    // Listado principal con filtro de categoría
    @GetMapping
    public String verCatalogo(@RequestParam(name = "categoria", required = false) Long categoriaId, Model model) {
        List<Producto> productos;

        if (categoriaId != null) {
            productos = productoService.obtenerDisponiblesPorCategoria(categoriaId);
        } else {
            productos = productoService.obtenerTodosDisponibles();
        }

        model.addAttribute("productos", productos);
        model.addAttribute("categorias", categoriaService.listarCategorias());
        model.addAttribute("categoriaSeleccionada", categoriaId);
        return "publico/catalogo";
    }

    // Detalle individual del producto
    @GetMapping("/producto/{id}")
    public String detalleProducto(@PathVariable Long id, Model model) {
        Producto producto = productoService.obtenerProducto(id);

        // Validamos que el producto exista y tenga stock para mostrarlo
        if (producto == null) return "redirect:/catalogo";

        model.addAttribute("producto", producto);
        model.addAttribute("variantes", varianteService.obtenerPorProducto(id));
        return "publico/detalle";
    }
}