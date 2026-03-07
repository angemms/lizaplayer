// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get untitledTrack => 'Безымянный трек';

  @override
  String get myWave => 'Моя волна';

  @override
  String get personalRecommendations => 'Персональные рекомендации';

  @override
  String get loading => 'Загрузка...';

  @override
  String get startMyWave => 'Запустить мою волну';

  @override
  String get tracks => 'треков';

  @override
  String get personalWave => 'персональная волна';

  @override
  String get newWave => 'Новая волна';

  @override
  String get myLikes => 'Мои лайки';

  @override
  String get noLikesYet => 'Пока нет лайков';

  @override
  String get likeToFill => 'Лайкайте треки, чтобы заполнить этот плейлист';

  @override
  String get playlists => 'Плейлисты';

  @override
  String get syncComingSoon => 'Синхронизация скоро';

  @override
  String get theme => 'Тема';

  @override
  String get light => 'Светлая';

  @override
  String get dark => 'Тёмная';

  @override
  String get system => 'Системная';

  @override
  String get mainColor => 'Основной цвет';

  @override
  String get language => 'Язык';

  @override
  String get english => 'Английский';

  @override
  String get russian => 'Русский';

  @override
  String get searchTracks => 'Поиск треков...';

  @override
  String get find => 'Найти';

  @override
  String get findSomething => 'Найдите что-нибудь';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get languageSection => 'Язык';

  @override
  String get clearCache => 'Очистить кэш';

  @override
  String get clearCacheSubtitle => 'Очистить временные файлы';

  @override
  String get logout => 'Выйти';

  @override
  String get logoutSubtitle => 'Выйти из аккаунта';

  @override
  String get settings => 'Настройки';

  @override
  String get home => 'Главная';

  @override
  String get myPlaylists => 'Мои плейлисты';

  @override
  String get dataAndAccount => 'Данные и аккаунт';

  @override
  String get glassInterface => 'Стеклянный интерфейс';

  @override
  String get customBackground => 'Пользовательский фон';

  @override
  String get directLinkToGifOrImage => 'Прямая ссылка на GIF или изображение';

  @override
  String get urlExample => 'https://i.imgur.com/abc123.gif или .jpg';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get clear => 'Очистить';

  @override
  String get installed => 'Установлен';

  @override
  String get notInstalled => 'Не установлен';

  @override
  String get noColor => 'Без цвета';

  @override
  String get queue => 'Очередь';

  @override
  String get queueEmpty => 'Очередь пуста';

  @override
  String get backgroundBlur => 'Размытие фона';

  @override
  String searchResultsFor(Object query) {
    return 'Результаты поиска для \"$query\"';
  }
}
