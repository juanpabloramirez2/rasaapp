package com.rasadeportes.rasaapp.controller;

import com.rasadeportes.rasaapp.model.Imagen;
import com.rasadeportes.rasaapp.services.ImagenService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@Controller
@RequestMapping("/dashboard/imagenes")
public class ImagenController {

    private final ImagenService imagenService;

    public ImagenController(ImagenService imagenService) {
        this.imagenService = imagenService;
    }

    // ✔ Listar imágenes por producto
    @GetMapping("/producto/{productoId}")
    public String listarImagenes(
            @PathVariable Long productoId,
            Model model) {

        model.addAttribute(
                "imagenes",
                imagenService.obtenerPorProducto(productoId)
        );

        model.addAttribute("productoId", productoId);

        return "imagenes/listado";
    }

    // ✔ Mostrar formulario nueva imagen
    @GetMapping("/nueva/{productoId}")
    public String nuevaImagen(
            @PathVariable Long productoId,
            Model model) {

        model.addAttribute("imagen", new Imagen());
        model.addAttribute("productoId", productoId);

        return "imagenes/formulario";
    }

    @PostMapping("/guardar/{productoId}")
    public String guardarImagen(
            @PathVariable Long productoId,
            @RequestParam(value = "id", required = false) Long id, // Capturamos el ID oculto
            @RequestParam(value = "archivo", required = false) MultipartFile archivo, // Opcional al editar
            @RequestParam(value = "esPrincipal", required = false) Boolean esPrincipal) {

        imagenService.guardarImagen(
                productoId,
                id, // Pasamos el ID al service
                archivo,
                esPrincipal != null
        );

        return "redirect:/dashboard/imagenes/producto/" + productoId;
    }

    // ✔ Editar imagen
    @GetMapping("/editar/{id}")
    public String editarImagen(
            @PathVariable Long id,
            Model model) {

        Imagen imagen =
                imagenService.obtenerImagen(id);

        model.addAttribute("imagen", imagen);

        model.addAttribute(
                "productoId",
                imagen.getProducto().getId()
        );

        return "imagenes/formulario";
    }

    @GetMapping("/eliminar/{id}")
    public String eliminarImagen(
            @PathVariable Long id) {

        Long productoId =
                imagenService.obtenerProductoIdPorImagenId(id);

        imagenService.eliminarImagen(id);

        return "redirect:/dashboard/imagenes/producto/" + productoId;
    }
}