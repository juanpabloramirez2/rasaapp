package com.rasadeportes.rasaapp.services;

import com.rasadeportes.rasaapp.model.Producto;
import com.rasadeportes.rasaapp.model.Variante;
import com.rasadeportes.rasaapp.repository.ProductoRepository;
import com.rasadeportes.rasaapp.repository.VarianteRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class VarianteService {

    private final VarianteRepository varianteRepository;
    private final ProductoRepository productoRepository;

    public VarianteService(VarianteRepository varianteRepository,
                           ProductoRepository productoRepository) {
        this.varianteRepository = varianteRepository;
        this.productoRepository = productoRepository;
    }

    public List<Variante> listarVariantes(){
        return varianteRepository.findAll();
    }

    public Variante guardarVariante(Long productoId, Variante variante){
        Producto producto = productoRepository.findById(productoId)
                .orElseThrow(() -> new RuntimeException("Producto no encontrado: " + productoId));
        variante.setProducto(producto);
        return varianteRepository.save(variante);
    }

    public Variante obtenerVariante(Long id){
        return varianteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Variante no encontrada: " + id));
    }

    public void eliminarVariante(Long id){
        varianteRepository.deleteById(id);
    }

    public List<Variante> obtenerPorProducto(Long productoId){
        return varianteRepository.findByProductoId(productoId);
    }

    public Long obtenerProductoIdPorVarianteId(Long varianteId){
        return varianteRepository.findById(varianteId)
                .orElseThrow(() -> new RuntimeException("Variante no encontrada: " + varianteId))
                .getProducto()
                .getId();
    }

    public Integer obtenerStockTotal(Long productoId) {
        return varianteRepository.obtenerStockTotalPorProducto(productoId);
    }
}