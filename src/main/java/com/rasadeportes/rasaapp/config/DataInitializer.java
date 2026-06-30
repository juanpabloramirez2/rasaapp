package com.rasadeportes.rasaapp.config;

import com.rasadeportes.rasaapp.model.Usuario;
import com.rasadeportes.rasaapp.repository.UsuarioRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class DataInitializer {

    @Value("${app.admin.username}")
    private String adminUsername;

    @Value("${app.admin.password}")
    private String adminPassword;

    @Bean
    CommandLineRunner crearUsuarioInicial(
            UsuarioRepository usuarioRepository,
            PasswordEncoder passwordEncoder) {

        return args -> {
            if (usuarioRepository.findByUsername(adminUsername).isEmpty()) {
                Usuario admin = new Usuario();
                admin.setUsername(adminUsername);
                admin.setPassword(passwordEncoder.encode(adminPassword));
                admin.setRol("ADMIN");
                admin.setEnabled(true);
                usuarioRepository.save(admin);
            }
        };
    }
}
