package com.payflex.backend;

import com.payflex.backend.config.PayflexProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
@EnableConfigurationProperties(PayflexProperties.class)
public class PayflexBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(PayflexBackendApplication.class, args);
    }
}
