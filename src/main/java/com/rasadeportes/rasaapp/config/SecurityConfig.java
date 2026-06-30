package com.rasadeportes.rasaapp.config;

import com.rasadeportes.rasaapp.services.UsuarioDetailsService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final UsuarioDetailsService usuarioDetailsService;
    private final PasswordEncoder passwordEncoder;

    public SecurityConfig(
            UsuarioDetailsService usuarioDetailsService,
            PasswordEncoder passwordEncoder) {

        this.usuarioDetailsService = usuarioDetailsService;
        this.passwordEncoder = passwordEncoder;
    }

    @Bean
    public SecurityFilterChain filterChain(
            HttpSecurity http) throws Exception {

        http

                .authorizeHttpRequests(auth -> auth

                        // login libre
                        .requestMatchers("/login")
                        .permitAll()

                        .requestMatchers(
                                "/catalogo/**",
                                "/",
                                "/productos-publicos/**"
                        ).permitAll()

                        // recursos estáticos, health check y página de error
                        .requestMatchers(
                                "/css/**",
                                "/js/**",
                                "/uploads/**",
                                "/webjars/**",
                                "/mantis/**",
                                "/actuator/health",
                                "/actuator/health/**",
                                "/error"
                        ).permitAll()

                        // dashboard protegido
                        .requestMatchers("/dashboard/**")
                        .hasRole("ADMIN")

                        // todo lo demás
                        .anyRequest()
                        .authenticated()
                )

                .formLogin(form -> form

                        .loginPage("/login")

                        .loginProcessingUrl("/login")

                        .defaultSuccessUrl(
                                "/dashboard/productos",
                                true
                        )

                        .failureUrl("/login?error=true")

                        .permitAll()
                )

                .logout(logout -> logout

                        .logoutUrl("/logout")

                        .logoutSuccessUrl("/login")

                        .permitAll()
                );

        return http.build();
    }

    // 🔐 ESTE VA AQUÍ
    @Bean
    public AuthenticationManager authenticationManager(
            AuthenticationConfiguration config)
            throws Exception {

        return config.getAuthenticationManager();
    }

    @Bean
    public DaoAuthenticationProvider authenticationProvider() {

        DaoAuthenticationProvider provider =
                new DaoAuthenticationProvider(usuarioDetailsService);

        provider.setPasswordEncoder(
                passwordEncoder
        );

        return provider;
    }

}