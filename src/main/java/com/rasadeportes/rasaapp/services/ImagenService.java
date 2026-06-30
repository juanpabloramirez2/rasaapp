package com.rasadeportes.rasaapp.services;

import com.rasadeportes.rasaapp.model.Imagen;
import com.rasadeportes.rasaapp.model.Producto;
import com.rasadeportes.rasaapp.repository.ImagenRepository;
import com.rasadeportes.rasaapp.repository.ProductoRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.UUID;

@Service
public class ImagenService {

    private final ImagenRepository imagenRepository;
    private final ProductoRepository productoRepository;

    @Value("${app.uploads.path:uploads}")
    private String uploadsPath;

    public ImagenService(ImagenRepository imagenRepository, ProductoRepository productoRepository) {
        this.imagenRepository = imagenRepository;
        this.productoRepository = productoRepository;
    }

    public void guardarImagen(Long productoId, Long id, MultipartFile archivo, Boolean esPrincipal) {
        try {
            Producto producto = productoRepository.findById(productoId)
                    .orElseThrow(() -> new RuntimeException("Producto no encontrado"));

            Imagen imagen;

            // ¿Estamos editando o creando?
            if (id != null) {
                imagen = imagenRepository.findById(id)
                        .orElseThrow(() -> new RuntimeException("Imagen no encontrada"));
            } else {
                imagen = new Imagen();
                imagen.setProducto(producto);
            }

            // PROCESAR ARCHIVO (Solo si se subió uno nuevo)
            if (archivo != null && !archivo.isEmpty()) {
                Path rutaDirectorio = Paths.get(uploadsPath).toAbsolutePath();
                if (!Files.exists(rutaDirectorio)) {
                    Files.createDirectories(rutaDirectorio);
                }

                String nombreArchivo = UUID.randomUUID() + "_" + archivo.getOriginalFilename();
                Path rutaArchivo = rutaDirectorio.resolve(nombreArchivo);
                archivo.transferTo(rutaArchivo.toFile());

                // La URL pública siempre es /uploads/* (el resource handler la sirve)
                imagen.setUrl("/uploads/" + nombreArchivo);
            }

            // Lógica de imagen principal
            if (esPrincipal) {
                List<Imagen> imagenes = imagenRepository.findByProductoId(productoId);
                for (Imagen img : imagenes) {
                    img.setEsPrincipal(false);
                }
                imagenRepository.saveAll(imagenes);
            }

            imagen.setEsPrincipal(esPrincipal);
            imagenRepository.save(imagen);

        } catch (IOException e) {
            throw new RuntimeException("Error guardando imagen: " + e.getMessage());
        }
    }

    public List<Imagen> obtenerPorProducto(Long productoId) {
        return imagenRepository.findByProductoId(productoId);
    }

    public Imagen obtenerImagen(Long id) {
        return imagenRepository.findById(id).orElse(null);
    }

    public void eliminarImagen(Long id) {
        // Opcional: Aquí podrías añadir lógica para borrar el archivo físico también
        imagenRepository.deleteById(id);
    }

    public Long obtenerProductoIdPorImagenId(Long imagenId) {
        return imagenRepository.findById(imagenId)
                .orElseThrow(() -> new RuntimeException("Imagen no encontrada: " + imagenId))
                .getProducto()
                .getId();
    }
}