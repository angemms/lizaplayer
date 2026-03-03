### О плеере

- opensource
- Полностью кастомный дизайн в тёмном/светлом стиле
- Выбор акцентного цвета (аква, красный, серый, оранжевый, фиолетовый и т.д.)
- Приятный интерфейс
- Моя волна
- Поиск треков
- Плавные анимации и внимание к мелочам
- Работает на Linux (и легко портируется)

### Скриншоты

![q1](https://github.com/user-attachments/assets/343af806-8383-4156-a12b-7247209be9b8)
![q2](https://github.com/user-attachments/assets/74ea21f1-95b9-4b33-bc3b-cec8670281c2)
![q3](https://github.com/user-attachments/assets/f23bfcd7-31a1-4711-a4da-c35a27f2f81c)
![q4](https://github.com/user-attachments/assets/dacf20e7-67e8-4300-8d22-69f9b3a5cf88)

### Как запустить

- Скачиваем последний релиз
- Разархивируем
- Запускаем исполняемый файл

### Как запустить (альтернатива)

```bash
# Клонируем
git clone https://github.com/lizapropanol/lizaplayer.git
cd lizaplayer

# Устанавливаем зависимости
flutter pub get

# Запускаем
flutter run -d linux --release
```

### Как получить токен Yandex Music

Открой music.yandex.ru в браузере
Нажми F12 → вкладка Application → Local Storage → https://music.yandex.ru
Найди ключ access_token или oauth и скопируй его
Вставь в lizaplayer и нажми "Сохранить и войти"

### Технологии

Flutter + Riverpod
just_audio
yandex_music API
shared_preferences
window_manager
