package com.rasadeportes.rasaapp.controller;

import com.rasadeportes.rasaapp.model.Producto;
import com.rasadeportes.rasaapp.model.Categoria;
import com.rasadeportes.rasaapp.services.ProductoService;
import com.rasadeportes.rasaapp.services.CategoriaService;
import com.rasadeportes.rasaapp.services.VarianteService;
import com.rasadeportes.rasaapp.model.Variante;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

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

        List<Variante> variantes = varianteService.obtenerPorProducto(id);

        model.addAttribute("producto", producto);
        model.addAttribute("variantes", variantes);
        model.addAttribute("coloresDisponibles", colores(variantes));
        model.addAttribute("tallasDisponibles", tallas(variantes));
        return "publico/detalle";
    }

    // Colores únicos entre las variantes con stock (evita repetidos cuando
    // solo cambia la talla, ej. Rojo/M y Rojo/L comparten color)
    private List<String> colores(List<Variante> variantes) {
        return variantes.stream()
                .filter(v -> v.getColor() != null && !v.getColor().isBlank() && v.getCantidad() > 0)
                .map(Variante::getColor)
                .distinct()
                .collect(Collectors.toList());
    }

    // Tallas únicas entre las variantes con stock
    private List<String> tallas(List<Variante> variantes) {
        return variantes.stream()
                .filter(v -> v.getTalla() != null && !v.getTalla().isBlank() && v.getCantidad() > 0)
                .map(Variante::getTalla)
                .distinct()
                .collect(Collectors.toList());
    }
}