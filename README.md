# 🇪🇨 Ecuaventura: Reciclaje Tangible y Gamificado

![Status](https://img.shields.io/badge/Status-En_Desarrollo-yellow)
![Godot](https://img.shields.io/badge/Godot-v4.x-blue)
![Python](https://img.shields.io/badge/Python-3.9+-green)
![Arduino](https://img.shields.io/badge/Hardware-Arduino_Mega-teal)
![HCI](https://img.shields.io/badge/Focus-HCI%20%26%20Gamification-orange)

**Ecuaventura** es un sistema interactivo diseñado para enseñar a niños sobre la clasificación de residuos y el reciclaje mediante la fusión del mundo físico y digital. 

Este proyecto implementa una **Interfaz Tangible de Usuario (TUI)** donde objetos físicos reales controlan un entorno virtual gamificado, apoyado por un sistema de Inteligencia Artificial que adapta la dificultad en tiempo real para mantener el *engagement* del usuario.

---

## 🎯 Enfoque HCI (Interacción Humano-Computador)

Este proyecto explora conceptos clave de la interacción moderna:

1.  **Interacción Tangible:** A diferencia de presionar botones en una pantalla, los niños manipulan "basura" física (representada por tokens NFC). Esto refuerza el aprendizaje motor y la asociación cognitiva entre el objeto real y su categoría de reciclaje.
2.  **Feedback Multimodal:** El sistema ofrece retroalimentación inmediata:
    * **Física:** Acción de depositar el objeto en el tacho.
    * **Visual/Auditiva:** El juego en Godot reacciona instantáneamente a la lectura del sensor.
3.  **Ajuste Dinámico de Dificultad (DDA):** Para mantener al usuario en el estado de "Flow", un modelo de Machine Learning analiza el desempeño del jugador y ajusta la velocidad o complejidad del juego automáticamente, evitando la frustración o el aburrimiento.

---

## 🏗️ Arquitectura del Sistema

El flujo de datos conecta el hardware físico con la lógica de negocio y la interfaz gráfica de la siguiente manera:

```mermaid
graph LR
    A[NTAG215 (Basura)] -->|NFC| B[Lectores RC522 (Tachos)]
    B -->|SPI| C[Arduino Mega 2560]
    C -->|Serial| D[Middleware Python]
    D -->|WebSockets| E[Interfaz Godot]
    E <-->|HTTP Request/Response| F[FastAPI Server + ML Model]