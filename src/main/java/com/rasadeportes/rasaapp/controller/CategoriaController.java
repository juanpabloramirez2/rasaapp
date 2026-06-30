package com.rasadeportes.rasaapp.controller;

import com.rasadeportes.rasaapp.model.Categoria;
import com.rasadeportes.rasaapp.services.CategoriaService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

@Controller
@RequestMapping("/dashboard/categorias")
public class CategoriaController {

    private final CategoriaService categoriaService;

    public CategoriaController(CategoriaService categoriaService) {
        this.categoriaService = categoriaService;
    }

    @GetMapping
    public String listarCategorias(Model model){
        model.addAttribute("categorias", categoriaService.listarCategorias());
        return "categoria/listado";
    }

    @GetMapping("/nueva-categoria")
    public String nuevaCategoria(Model model){
        model.addAttribute("categoria", new Categoria());
        return "categoria/formulario";
    }

    @PostMapping
    public String guardarCategoria(@ModelAttribute Categoria categoria){
        categoriaService.guardarCategoria(categoria);
        return "redirect:/dashboard/categorias";
    }

    @GetMapping("/editar/{id}")
    public String editarCategoria(@PathVariable Long id, Model model){
        Categoria categoria = categoriaService.obtenerCategoria(id);
        model.addAttribute("categoria", categoria);
        return "categoria/formulario";
    }

    @GetMapping("/eliminar/{id}")
    public String eliminar(@PathVariable Long id){
        categoriaService.eliminarCategoria(id);
        return "redirect:/dashboard/categorias";
    }


}
