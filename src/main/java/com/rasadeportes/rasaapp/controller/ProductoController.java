package com.rasadeportes.rasaapp.controller;

import com.rasadeportes.rasaapp.model.Producto;
import com.rasadeportes.rasaapp.services.CategoriaService;
import com.rasadeportes.rasaapp.services.ProductoService;
import com.rasadeportes.rasaapp.services.VarianteService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Controller
@RequestMapping("/dashboard/productos")
public class ProductoController {

    private final ProductoService productoService;
    private final CategoriaService categoriaService;
    private final VarianteService varianteService;

    public ProductoController(ProductoService productoService, CategoriaService categoriaService, VarianteService varianteService) {
        this.productoService = productoService;
        this.categoriaService = categoriaService;
        this.varianteService = varianteService;
    }

    @GetMapping
    public String listarProductos(Model model) {
        List<Producto> productos = productoService.listarProductos();

        Map<Long, Integer> stockPorProducto = productos.stream()
                .collect(Collectors.toMap(
                        Producto::getId,
                        p -> varianteService.obtenerStockTotal(p.getId())
                ));

        model.addAttribute("productos", productos);
        model.addAttribute("stockPorProducto", stockPorProducto);
        return "producto/listado";
    }

    @GetMapping("/nuevo-producto")
    public String nuevoProducto(Model model){
        model.addAttribute("producto", new Producto());
        model.addAttribute("categorias", categoriaService.listarCategorias());
        return "producto/formulario";
    }

    // MÉTODO CORREGIDO PARA EVITAR BORRADO DE IMÁGENES/VARIANTES
    @PostMapping
    public String guardarProducto(@ModelAttribute Producto producto){
        if (producto.getCategoria() == null){
            return "producto/formulario";
        }

        // 1. Verificamos si es una edición (tiene ID)
        if (producto.getId() != null) {
            // 2. Recuperamos el producto real que ya tiene las listas cargadas
            Producto productoExistente = productoService.obtenerProducto(producto.getId());

            // 3. Actualizamos manualmente solo los campos del formulario
            productoExistente.setNombre(producto.getNombre());
            productoExistente.setDescripcion(producto.getDescripcion());
            productoExistente.setPrecio(producto.getPrecio());
            productoExistente.setCategoria(producto.getCategoria());

            // 4. Guardamos el existente (que aún conserva sus fotos y variantes intactas)
            productoService.guardarProducto(productoExistente);
        } else {
            // Es un producto nuevo, se guarda normal
            productoService.guardarProducto(producto);
        }

        return "redirect:/dashboard/productos";
    }

    @GetMapping("/editar/{id}")
    public String editarProducto(@PathVariable Long id, Model model){
        Producto producto = productoService.obtenerProducto(id);
        model.addAttribute("producto", producto);
        model.addAttribute("categorias", categoriaService.listarCategorias());
        return "producto/formulario";
    }

    @GetMapping("/eliminar/{id}")
    public String eliminarProducto(@PathVariable Long id){
        productoService.eliminarProducto(id);
        return "redirect:/dashboard/productos";
    }
}
