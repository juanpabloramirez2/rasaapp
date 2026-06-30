package com.rasadeportes.rasaapp.services;

import com.rasadeportes.rasaapp.model.Categoria;
import com.rasadeportes.rasaapp.repository.CategoriaRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CategoriaService {

    private final CategoriaRepository categoriaRepository;

    public CategoriaService(CategoriaRepository categoriaRepository) {
        this.categoriaRepository = categoriaRepository;
    }

    public List<Categoria> listarCategorias(){
        return categoriaRepository.findAll();
    }

    public Categoria guardarCategoria(Categoria categoria){
        return categoriaRepository.save(categoria);
    }

    public Categoria obtenerCategoria(Long id){
        return categoriaRepository.findById(id).orElse(null);
    }

    public void eliminarCategoria(Long id){
        categoriaRepository.deleteById(id);
    }
}
