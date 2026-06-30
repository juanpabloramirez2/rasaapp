package com.rasadeportes.rasaapp.repository;

import com.rasadeportes.rasaapp.model.Categoria;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CategoriaRepository extends JpaRepository <Categoria, Long> {
}
