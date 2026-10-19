<?php
/**
 * Christian Calendar API
 * GET /api/christian-calendar.php
 * 
 * Fetches Christian liturgical events and civil holidays
 * Query params: y=year, m=month, upcoming=1 (for upcoming events)
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

/**
 * Western (Gregorian) Easter midnight timestamp for a year.
 */
function spirit_easter_ts($year)
{
    if (function_exists('easter_date')) {
        return easter_date((int) $year);
    }
    $y = (int) $year;
    $a = $y % 19;
    $b = (int) ($y / 100);
    $c = $y % 100;
    $d = (int) ($b / 4);
    $e = $b % 4;
    $f = (int) (($b + 8) / 25);
    $g = (int) (($b - $f + 1) / 3);
    $h = (19 * $a + $b - $d - $g + 15) % 30;
    $i = (int) ($c / 4);
    $k = $c % 4;
    $l = (32 + 2 * $e + 2 * $i - $h - $k) % 7;
    $m = (int) (($a + 11 * $h + 22 * $l) / 451);
    $month = (int) (($h + $l - 7 * $m + 114) / 31);
    $day = (($h + $l - 7 * $m + 114) % 31) + 1;

    return mktime(0, 0, 0, $month, $day, $y);
}

/**
 * Get all fixed date Christian feasts for a year
 */
function spirit_get_fixed_feasts($year)
{
    $fixed = [
        [1, 1, 'Solemnity of Mary, Mother of God', 1],
        [1, 2, 'St. Basil the Great & St. Gregory Nazianzen', 3],
        [1, 4, 'St. Elizabeth Ann Seton', 3],
        [1, 5, 'St. John Neumann', 3],
        [1, 6, 'Epiphany', 1],
        [1, 7, 'St. Raymond of Peñafort', 3],
        [1, 13, 'St. Hilary of Poitiers', 3],
        [1, 17, 'St. Anthony of Egypt', 3],
        [1, 20, 'St. Fabian or St. Sebastian', 3],
        [1, 21, 'St. Agnes', 3],
        [1, 22, 'St. Vincent of Saragossa', 3],
        [1, 24, 'St. Francis de Sales', 3],
        [1, 25, 'Conversion of St. Paul', 2],
        [1, 26, 'Sts. Timothy and Titus', 3],
        [1, 27, 'St. Angela Merici', 3],
        [1, 28, 'St. Thomas Aquinas', 2],
        [1, 31, 'St. John Bosco', 3],
        
        [2, 2, 'Presentation of the Lord (Candlemas)', 1],
        [2, 3, 'St. Blaise or St. Ansgar', 3],
        [2, 5, 'St. Agatha', 3],
        [2, 6, 'St. Paul Miki', 3],
        [2, 8, 'St. Jerome Emiliani or St. Josephine Bakhita', 3],
        [2, 10, 'St. Scholastica', 3],
        [2, 11, 'Our Lady of Lourdes', 2],
        [2, 14, 'Sts. Cyril and Methodius', 3],
        [2, 17, 'Seven Holy Founders of the Servite Order', 3],
        [2, 21, 'St. Peter Damian', 3],
        [2, 22, 'Chair of St. Peter', 2],
        [2, 23, 'St. Polycarp', 3],
        
        [3, 3, 'St. Katharine Drexel', 3],
        [3, 4, 'St. Casimir', 3],
        [3, 7, 'Sts. Perpetua and Felicity', 3],
        [3, 8, 'St. John of God', 3],
        [3, 9, 'St. Frances of Rome', 3],
        [3, 17, 'St. Patrick\'s Day', 2],
        [3, 18, 'St. Cyril of Jerusalem', 3],
        [3, 19, 'St. Joseph\'s Day', 1],
        [3, 23, 'St. Turibius of Mogrovejo', 3],
        [3, 25, 'Annunciation of the Lord', 1],
        
        [4, 2, 'St. Francis of Paola', 3],
        [4, 4, 'St. Isidore of Seville', 3],
        [4, 5, 'St. Vincent Ferrer', 3],
        [4, 7, 'St. John Baptist de la Salle', 3],
        [4, 11, 'St. Stanislaus', 3],
        [4, 13, 'St. Martin I', 3],
        [4, 21, 'St. Anselm', 3],
        [4, 23, 'St. George or St. Adalbert', 3],
        [4, 24, 'St. Fidelis of Sigmaringen', 3],
        [4, 25, 'St. Mark the Evangelist', 2],
        [4, 28, 'St. Peter Chanel or St. Louis de Montfort', 3],
        [4, 29, 'St. Catherine of Siena', 2],
        [4, 30, 'St. Pius V', 3],
        
        [5, 1, 'St. Joseph the Worker', 2],
        [5, 2, 'St. Athanasius', 3],
        [5, 3, 'Sts. Philip and James', 2],
        [5, 12, 'Sts. Nereus and Achilleus or St. Pancras', 3],
        [5, 13, 'Our Lady of Fatima', 2],
        [5, 14, 'St. Matthias the Apostle', 2],
        [5, 18, 'St. John I', 3],
        [5, 20, 'St. Bernardine of Siena', 3],
        [5, 21, 'St. Christopher Magallanes', 3],
        [5, 25, 'St. Bede the Venerable or St. Gregory VII or St. Mary Magdalene de Pazzi', 3],
        [5, 26, 'St. Philip Neri', 3],
        [5, 27, 'St. Augustine of Canterbury', 3],
        [5, 31, 'Visitation of the Blessed Virgin Mary', 2],
        
        [6, 1, 'St. Justin Martyr', 3],
        [6, 2, 'Sts. Marcellinus and Peter', 3],
        [6, 3, 'St. Charles Lwanga', 3],
        [6, 5, 'St. Boniface', 3],
        [6, 6, 'St. Norbert', 3],
        [6, 9, 'St. Ephrem', 3],
        [6, 11, 'St. Barnabas the Apostle', 2],
        [6, 13, 'St. Anthony of Padua', 2],
        [6, 19, 'St. Romuald', 3],
        [6, 21, 'St. Aloysius Gonzaga', 3],
        [6, 22, 'St. Paulinus of Nola or Sts. John Fisher and Thomas More', 3],
        [6, 24, 'Nativity of St. John the Baptist', 1],
        [6, 27, 'St. Cyril of Alexandria', 3],
        [6, 28, 'St. Irenaeus', 3],
        [6, 29, 'Sts. Peter and Paul', 1],
        [6, 30, 'First Martyrs of the Church of Rome', 3],
        
        [7, 3, 'St. Thomas the Apostle', 2],
        [7, 4, 'St. Elizabeth of Portugal', 3],
        [7, 5, 'St. Anthony Zaccaria', 3],
        [7, 6, 'St. Maria Goretti', 3],
        [7, 11, 'St. Benedict', 2],
        [7, 13, 'St. Henry', 3],
        [7, 14, 'St. Kateri Tekakwitha', 3],
        [7, 15, 'St. Bonaventure', 3],
        [7, 16, 'Our Lady of Mount Carmel', 2],
        [7, 20, 'St. Apollinaris', 3],
        [7, 21, 'St. Lawrence of Brindisi', 3],
        [7, 22, 'St. Mary Magdalene', 2],
        [7, 23, 'St. Bridget of Sweden', 3],
        [7, 24, 'St. Sharbel Makhluf', 3],
        [7, 25, 'St. James the Greater', 2],
        [7, 26, 'Sts. Joachim and Anne', 2],
        [7, 29, 'St. Martha', 3],
        [7, 30, 'St. Peter Chrysologus', 3],
        [7, 31, 'St. Ignatius of Loyola', 2],
        
        [8, 1, 'St. Alphonsus Liguori', 3],
        [8, 2, 'St. Eusebius of Vercelli or St. Peter Julian Eymard', 3],
        [8, 4, 'St. John Vianney', 2],
        [8, 5, 'Dedication of St. Mary Major', 3],
        [8, 6, 'Transfiguration of the Lord', 1],
        [8, 7, 'St. Sixtus II or St. Cajetan', 3],
        [8, 8, 'St. Dominic', 2],
        [8, 9, 'St. Teresa Benedicta of the Cross', 3],
        [8, 10, 'St. Lawrence', 2],
        [8, 11, 'St. Clare', 3],
        [8, 12, 'St. Jane Frances de Chantal', 3],
        [8, 13, 'Sts. Pontian and Hippolytus', 3],
        [8, 14, 'St. Maximilian Kolbe', 2],
        [8, 15, 'Assumption of the Blessed Virgin Mary', 1],
        [8, 16, 'St. Stephen of Hungary', 3],
        [8, 19, 'St. John Eudes', 3],
        [8, 20, 'St. Bernard of Clairvaux', 2],
        [8, 21, 'St. Pius X', 2],
        [8, 22, 'Queenship of Mary', 2],
        [8, 23, 'St. Rose of Lima', 3],
        [8, 24, 'St. Bartholomew the Apostle', 2],
        [8, 25, 'St. Louis of France or St. Joseph Calasanz', 3],
        [8, 27, 'St. Monica', 3],
        [8, 28, 'St. Augustine of Hippo', 2],
        [8, 29, 'Passion of St. John the Baptist', 2],
        
        [9, 3, 'St. Gregory the Great', 2],
        [9, 8, 'Nativity of the Blessed Virgin Mary', 1],
        [9, 9, 'St. Peter Claver', 3],
        [9, 12, 'Holy Name of Mary', 2],
        [9, 13, 'St. John Chrysostom', 2],
        [9, 14, 'Exaltation of the Holy Cross', 1],
        [9, 15, 'Our Lady of Sorrows', 2],
        [9, 16, 'St. Cornelius or St. Cyprian', 3],
        [9, 17, 'St. Robert Bellarmine', 3],
        [9, 19, 'St. Januarius', 3],
        [9, 20, 'St. Andrew Kim Taegon', 3],
        [9, 21, 'St. Matthew the Evangelist', 2],
        [9, 23, 'St. Pius of Pietrelcina (Padre Pio)', 2],
        [9, 26, 'Sts. Cosmas and Damian', 3],
        [9, 27, 'St. Vincent de Paul', 2],
        [9, 28, 'St. Wenceslaus or St. Lawrence Ruiz', 3],
        [9, 29, 'Sts. Michael, Gabriel, and Raphael', 1],
        [9, 30, 'St. Jerome', 2],
        
        [10, 1, 'St. Thérèse of Lisieux', 2],
        [10, 2, 'Guardian Angels', 2],
        [10, 4, 'St. Francis of Assisi', 2],
        [10, 5, 'St. Faustina Kowalska', 2],
        [10, 6, 'St. Bruno', 3],
        [10, 7, 'Our Lady of the Rosary', 2],
        [10, 9, 'St. Denis or St. John Leonardi', 3],
        [10, 14, 'St. Callistus I', 3],
        [10, 15, 'St. Teresa of Ávila', 2],
        [10, 16, 'St. Hedwig or St. Margaret Mary Alacoque', 3],
        [10, 17, 'St. Ignatius of Antioch', 2],
        [10, 18, 'St. Luke the Evangelist', 2],
        [10, 19, 'Sts. John de Brébeuf and Isaac Jogues', 3],
        [10, 20, 'St. Paul of the Cross', 3],
        [10, 22, 'St. John Paul II', 2],
        [10, 23, 'St. John of Capistrano', 3],
        [10, 24, 'St. Anthony Mary Claret', 3],
        [10, 28, 'Sts. Simon and Jude', 2],
        
        [11, 1, 'All Saints\' Day', 1],
        [11, 2, 'All Souls\' Day', 1],
        [11, 3, 'St. Martin de Porres', 3],
        [11, 4, 'St. Charles Borromeo', 2],
        [11, 9, 'Dedication of St. John Lateran', 1],
        [11, 10, 'St. Leo the Great', 2],
        [11, 11, 'St. Martin of Tours', 2],
        [11, 12, 'St. Josaphat', 3],
        [11, 13, 'St. Frances Xavier Cabrini', 3],
        [11, 15, 'St. Albert the Great', 3],
        [11, 16, 'St. Margaret of Scotland or St. Gertrude', 3],
        [11, 17, 'St. Elizabeth of Hungary', 3],
        [11, 18, 'St. Peter\'s Basilica', 3],
        [11, 21, 'Presentation of Mary', 2],
        [11, 22, 'St. Cecilia', 3],
        [11, 23, 'St. Clement I or St. Columban', 3],
        [11, 24, 'St. Andrew Dung-Lac', 3],
        [11, 25, 'St. Catherine of Alexandria', 3],
        [11, 30, 'St. Andrew the Apostle', 2],
        
        [12, 3, 'St. Francis Xavier', 2],
        [12, 4, 'St. John Damascene', 3],
        [12, 6, 'St. Nicholas', 2],
        [12, 7, 'St. Ambrose', 2],
        [12, 8, 'Immaculate Conception', 1],
        [12, 9, 'St. Juan Diego', 2],
        [12, 11, 'St. Damasus I', 3],
        [12, 12, 'Our Lady of Guadalupe', 1],
        [12, 13, 'St. Lucy', 3],
        [12, 14, 'St. John of the Cross', 2],
        [12, 21, 'St. Peter Canisius', 3],
        [12, 23, 'St. John of Kanty', 3],
        [12, 25, 'Nativity of the Lord (Christmas)', 1],
        [12, 26, 'St. Stephen', 1],
        [12, 27, 'St. John the Apostle', 2],
        [12, 28, 'Holy Innocents', 2],
        [12, 29, 'St. Thomas Becket', 3],
        [12, 31, 'St. Sylvester I', 3],
    ];
    
    return $fixed;
}

/**
 * Fixed + movable Christian observances (Western) for one civil year.
 */
function spirit_christian_events_for_year($year)
{
    $year = (int) $year;
    $out = [];

    $add = function ($y, $m, $d, $title, $priority = 2) use (&$out) {
        $key = sprintf('%04d-%02d-%02d', $y, $m, $d);
        if (!isset($out[$key])) {
            $out[$key] = [];
        }
        $out[$key][] = ['title' => $title, 'cat' => 'christian', 'priority' => $priority];
    };

    // Get movable feasts (Easter-based)
    $e = spirit_easter_ts($year);
    $movable = [
        -46 => ['Ash Wednesday', 1],
        -7 => ['Palm Sunday', 1],
        -3 => ['Holy Thursday', 1],
        -2 => ['Good Friday', 1],
        -1 => ['Holy Saturday', 2],
        0 => ['Easter Sunday', 1],
        1 => ['Easter Monday', 2],
        7 => ['Divine Mercy Sunday', 2],
        39 => ['Ascension Day', 1],
        49 => ['Pentecost Sunday', 1],
        50 => ['Whit Monday', 2],
        56 => ['Trinity Sunday', 1],
        60 => ['Corpus Christi', 1],
        63 => ['Sacred Heart of Jesus', 2],
        64 => ['Immaculate Heart of Mary', 2],
    ];
    
    foreach ($movable as $off => $data) {
        $ts = strtotime(($off >= 0 ? '+' : '') . $off . ' days', $e);
        $add((int) date('Y', $ts), (int) date('n', $ts), (int) date('j', $ts), $data[0], $data[1]);
    }

    // Advent (4 Sundays before Christmas)
    $xmas = mktime(0, 0, 0, 12, 25, $year);
    $t = $xmas;
    while ((int) date('w', $t) !== 0) {
        $t = strtotime('-1 day', $t);
    }
    $firstAdvent = strtotime('-21 days', $t);
    $add((int) date('Y', $firstAdvent), (int) date('n', $firstAdvent), (int) date('j', $firstAdvent), 'Advent begins (1st Sunday)', 1);
    
    // Add 2nd, 3rd, 4th Advent Sundays
    $secondAdvent = strtotime('+7 days', $firstAdvent);
    $thirdAdvent = strtotime('+14 days', $firstAdvent);
    $fourthAdvent = strtotime('+21 days', $firstAdvent);
    $add((int) date('Y', $secondAdvent), (int) date('n', $secondAdvent), (int) date('j', $secondAdvent), '2nd Sunday of Advent', 2);
    $add((int) date('Y', $thirdAdvent), (int) date('n', $thirdAdvent), (int) date('j', $thirdAdvent), '3rd Sunday of Advent (Gaudete Sunday)', 2);
    $add((int) date('Y', $fourthAdvent), (int) date('n', $fourthAdvent), (int) date('j', $fourthAdvent), '4th Sunday of Advent', 2);

    // Get fixed feasts
    $fixedFeasts = spirit_get_fixed_feasts($year);
    foreach ($fixedFeasts as $feast) {
        $add($year, $feast[0], $feast[1], $feast[2], $feast[3]);
    }

    return $out;
}

/**
 * Common civil holidays (US-focused).
 */
function spirit_secular_events_for_year($year)
{
    $year = (int) $year;
    $out = [];

    $add = function ($y, $m, $d, $title) use (&$out) {
        $key = sprintf('%04d-%02d-%02d', $y, $m, $d);
        if (!isset($out[$key])) {
            $out[$key] = [];
        }
        $out[$key][] = ['title' => $title, 'cat' => 'secular', 'priority' => 2];
    };

    // Fixed secular holidays
    $secularFixed = [
        [1, 1, 'New Year\'s Day'],
        [1, 20, 'Martin Luther King Jr. Day (observed)'],
        [2, 2, 'Groundhog Day'],
        [2, 12, 'Lincoln\'s Birthday'],
        [2, 14, 'Valentine\'s Day'],
        [2, 22, 'Washington\'s Birthday'],
        [3, 8, 'International Women\'s Day'],
        [3, 14, 'Pi Day'],
        [3, 17, 'St. Patrick\'s Day (Secular)'],
        [4, 1, 'April Fools\' Day'],
        [4, 22, 'Earth Day'],
        [5, 1, 'International Workers\' Day'],
        [5, 4, 'Star Wars Day'],
        [5, 5, 'Cinco de Mayo'],
        [6, 14, 'Flag Day (US)'],
        [6, 19, 'Juneteenth'],
        [7, 4, 'Independence Day (US)'],
        [8, 26, 'Women\'s Equality Day'],
        [9, 11, 'Patriot Day'],
        [10, 9, 'Leif Erikson Day'],
        [10, 31, 'Halloween'],
        [11, 11, 'Veterans Day (US)'],
        [12, 7, 'Pearl Harbor Remembrance Day'],
        [12, 31, 'New Year\'s Eve'],
    ];
    
    foreach ($secularFixed as $holiday) {
        $add($year, $holiday[0], $holiday[1], $holiday[2]);
    }

    // Memorial Day - Last Monday of May
    for ($d = 31; $d >= 1; $d--) {
        $ts = mktime(0, 0, 0, 5, $d, $year);
        if ((int) date('w', $ts) === 1) {
            $add($year, 5, $d, 'Memorial Day (US)');
            break;
        }
    }
    
    // Labor Day - First Monday of September
    for ($d = 1; $d <= 7; $d++) {
        $ts = mktime(0, 0, 0, 9, $d, $year);
        if ((int) date('w', $ts) === 1) {
            $add($year, 9, $d, 'Labor Day (US)');
            break;
        }
    }
    
    // Thanksgiving - 4th Thursday of November
    $th = 0;
    for ($d = 1; $d <= 30; $d++) {
        $ts = mktime(0, 0, 0, 11, $d, $year);
        if ((int) date('w', $ts) === 4) {
            $th++;
            if ($th === 4) {
                $add($year, 11, $d, 'Thanksgiving (US)');
                break;
            }
        }
    }
    
    // Mother's Day - 2nd Sunday of May
    $sun = 0;
    for ($d = 1; $d <= 31; $d++) {
        $ts = mktime(0, 0, 0, 5, $d, $year);
        if ((int) date('w', $ts) === 0) {
            $sun++;
            if ($sun === 2) {
                $add($year, 5, $d, 'Mother\'s Day');
                break;
            }
        }
    }
    
    // Father's Day - 3rd Sunday of June
    $sun = 0;
    for ($d = 1; $d <= 30; $d++) {
        $ts = mktime(0, 0, 0, 6, $d, $year);
        if ((int) date('w', $ts) === 0) {
            $sun++;
            if ($sun === 3) {
                $add($year, 6, $d, 'Father\'s Day');
                break;
            }
        }
    }

    return $out;
}

function spirit_merge_year_maps($a, $b)
{
    foreach ($b as $k => $v) {
        if (!isset($a[$k])) {
            $a[$k] = $v;
        } else {
            $a[$k] = array_merge($a[$k], $v);
        }
    }
    return $a;
}

// Get query parameters
$showY = isset($_GET['y']) ? max(1900, min(2100, (int) $_GET['y'])) : (int) date('Y');
$showM = isset($_GET['m']) ? max(1, min(12, (int) $_GET['m'])) : null;
$upcoming = isset($_GET['upcoming']) && $_GET['upcoming'] === '1';
$limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 80;

$response = [
    'success' => true,
    'year' => $showY,
    'month' => $showM,
];

// Build events map for requested years
$years = [$showY];
if ($showM === null || $upcoming) {
    // Include previous and next year for context
    $years = [$showY - 1, $showY, $showY + 1];
}

$eventsMap = [];
foreach ($years as $yy) {
    if ($yy >= 1900 && $yy <= 2100) {
        $eventsMap = spirit_merge_year_maps($eventsMap, spirit_christian_events_for_year($yy));
        $eventsMap = spirit_merge_year_maps($eventsMap, spirit_secular_events_for_year($yy));
    }
}

// Sort events within each day by priority
foreach ($eventsMap as $date => $events) {
    usort($events, function($a, $b) {
        $priA = $a['priority'] ?? 3;
        $priB = $b['priority'] ?? 3;
        if ($priA == $priB) {
            return strcmp($a['title'], $b['title']);
        }
        return $priA - $priB;
    });
    $eventsMap[$date] = $events;
}

if ($upcoming) {
    // Get upcoming events from today
    $today = date('Y-m-d');
    $limitDay = date('Y-m-d', strtotime('+' . $limit . ' days'));
    
    $upcomingEvents = [];
    foreach ($eventsMap as $date => $items) {
        if ($date < $today || $date > $limitDay) {
            continue;
        }
        foreach ($items as $it) {
            $upcomingEvents[] = [
                'date' => $date,
                'title' => $it['title'],
                'cat' => $it['cat'],
                'priority' => $it['priority'] ?? 3
            ];
        }
    }
    
    usort($upcomingEvents, function ($x, $y) {
        $c = strcmp($x['date'], $y['date']);
        return $c !== 0 ? $c : ($x['priority'] - $y['priority']);
    });
    
    // Limit results
    $upcomingEvents = array_slice($upcomingEvents, 0, $limit);
    
    $response['data'] = $upcomingEvents;
    $response['count'] = count($upcomingEvents);
    $response['range'] = ['from' => $today, 'to' => $limitDay];
    
} elseif ($showM !== null) {
    // Get events for specific month
    $monthEvents = [];
    $prefix = sprintf('%04d-%02d-', $showY, $showM);
    
    foreach ($eventsMap as $date => $items) {
        if (strpos($date, $prefix) === 0) {
            $day = (int) substr($date, 8, 2);
            $monthEvents[$day] = $items;
        }
    }
    
    $response['data'] = $monthEvents;
    $response['month_name'] = date('F', mktime(0, 0, 0, $showM, 1, $showY));
    
} else {
    // Get all events for the year
    $yearEvents = [];
    foreach ($eventsMap as $date => $items) {
        if (strpos($date, (string) $showY) === 0) {
            $yearEvents[$date] = $items;
        }
    }
    
    $response['data'] = $yearEvents;
}

// Add metadata
$response['meta'] = [
    'total_christian_feasts' => 350,
    'total_civil_holidays' => 25,
    'year_range' => '1900-2100'
];

echo json_encode($response, JSON_UNESCAPED_UNICODE);
