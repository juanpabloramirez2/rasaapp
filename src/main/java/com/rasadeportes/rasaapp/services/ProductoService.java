package com.rasadeportes.rasaapp.services;

import com.rasadeportes.rasaapp.model.Producto;
import com.rasadeportes.rasaapp.repository.ProductoRepository;
import com.rasadeportes.rasaapp.repository.VarianteRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class ProductoService {

    private final ProductoRepository productoRepository;
    private final VarianteRepository varianteRepository;

    public ProductoService(ProductoRepository productoRepository, VarianteRepository varianteRepository) {
        this.productoRepository = productoRepository;
        this.varianteRepository = varianteRepository;
    }

    public List<Producto> listarProductos(){
        return productoRepository.findAll();
    }

    public Producto guardarProducto(Producto producto){
        return productoRepository.save(producto);
    }

    public Producto obtenerProducto(Long id){
        return productoRepository.findById(id).orElse(null);
    }

    public void eliminarProducto(Long id){
        productoRepository.deleteById(id);
    }

    public Integer obtenerStockTotal(Long productoId){
        return varianteRepository.obtenerStockTotalPorProducto(productoId);
    }



    //Para el catálogo
    @Transactional(readOnly = true)
    public List<Producto> obtenerTodosDisponibles() {
        return productoRepository.findAll().stream()
                .filter(p -> p.getImagenes() != null && !p.getImagenes().isEmpty()) // Que tenga fotos
                .filter(p -> obtenerStockTotal(p.getId()) > 0) // Que tenga stock
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<Producto> obtenerDisponiblesPorCategoria(Long categoriaId) {
        return obtenerTodosDisponibles().stream()
                .filter(p -> p.getCategoria().getId().equals(categoriaId))
                .collect(Collectors.toList());
    }
}
