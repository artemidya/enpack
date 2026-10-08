<font size=5>
<h2>Seam Carving</h2>
В фильтре реализован <a href=https://en.wikipedia.org/wiki/Seam_carving>одноимённый алгоритм</a> для масштабирования изображения с учётом содержимого. Исходный код собирается при помощи <a href=https://flatassembler.net/download.php>FASM</a> версии 1.73.31.<p>
<table><tr><td><img width=100% src=Readme/1.gif><td width=1%><td><img width=100% src=Readme/2.gif></table>
<h2>Системные требования</h2>
<table  style="font-size:100%"><tr><td>Операционная система:<td>Windows XP или выше
<tr><td>Программное обеспечение:<td>Corel Draw версии 13 или выше
<tr><td>Процессор:<td>с поддержкой SSE4.1
</table>
<h2>Установка</h2>
Скопировать файл 8bf соответствующей архитектуры (<a href=https://github.com/fersatgit/Seam-Carving/releases/download/v1.1/SC_x86.8bf>x86</a> или <a href=https://github.com/fersatgit/Seam-Carving/releases/download/v1.1/SC_x64.8bf>x64</a>) в каталог Plugins. Расположение каталога указывается в параметрах CorelDraw.<p><img src=Readme/1.png>
<h2>Работа с фильтром</h2>
Для того, чтобы применить фильтр нужно:
<ol><li>Выделить растр в режиме RGB или CMYK
<li>Вызвать пункт меню "Растровые изображения->Подключаемые модули->tiny filters->Seam Carving"
<li>Пометить высоко-приоритетные участки левой клавишей мыши (зелёный цвет) и низко-приоритетные участки правой клавишей мыши (красный цвет)
<li>Нажать кнопку "Применить", затем "OK" для применения фильтра либо закрыть окно для отмены изменений.</ol>
В окне предварительного просмотра доступны следующие клавиши:
<table style="font-size:100%"><tr><td align=center width=200rem><img width=30% src=Readme/l.svg><td>Повысить приоритет участка изображения<td align=center width=200rem><img width=30% src=Readme/s.svg><td>Изменение размера кисти
<tr><td align=center><img width=30% src=Readme/r.svg><td>Понизить приоритет участка изображения<td align=center><img align=middle width=30% src=Readme/c.svg><b> + <img align=middle width=30% src=Readme/m.svg><td>Перетаскивание изображения
<tr><td align=center><img width=30% src=Readme/m.svg><td>Установить приоритет участка изображения по умолчанию<td align=center><img align=middle width=30% src=Readme/c.svg><b> + <img align=middle width=30% src=Readme/s.svg><td>Изменение масштаба
</table>
<h2>Ограничения</h2>
<ul><li>Поддерживается только RGB и CMYK
<li>Альфа-канал будет удалён при обработке
<li>Угол поворота не учитывается
<li>Минимальный размер изображения 4x4
<li>Для изображений в режиме CMYK цвета в окне предварительного просмотра будут отображаться некорректно, но на результат работы это не повлияет

