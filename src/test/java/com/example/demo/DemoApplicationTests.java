package com.example.demo;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
class DemoApplicationTests {

    @Test
    void contextLoads() {
        assertTrue(true, "Application context loads successfully");
    }

    @Test
    void sampleUnitTest() {
    int expected = 999; // Cố tình làm đứt test
    int actual = 5 + 5;
    org.junit.jupiter.api.Assertions.assertEquals(expected, actual, "Math calculation should match");
}

}
