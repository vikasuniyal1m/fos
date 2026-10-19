<?php
/**
 * Add/Update Fruit Emojis Script
 * This script adds fruit images from uploads/fruitofspirit/ to the emojis table
 * Run this once to populate emojis with fruit images
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';

header('Content-Type: application/json');

// Fruit images mapping - maps emoji names to image files
// Based on https://fosmessenger.com/fruit-of-the-spirit/
// Correct mapping: Love→Strawberry, Joy→Pineapple, Peace→Watermelon, Patience→Banana,
// Kindness→Orange, Goodness→Kiwi, Faithfulness→Cherry, Meekness→Grapes, Self-Control→Apple
// Har fruit ke saare variants (01, 02, 03) add kar rahe hain
$fruitEmojis = [
    // Love - Strawberry (using images/Strawberry.png as we don't have strawberry in fruitofspirit folder)
    // Note: If strawberry images are added to fruitofspirit folder, update this
    [
        'name' => 'Love',
        'emoji_char' => '❤️',
        'code' => 'love_01',
        'image_url' => 'uploads/images/Strawberry.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Agape love - the fruit of the Spirit. Love is patient, love is kind.',
    ],
    [
        'name' => 'Love',
        'emoji_char' => '❤️',
        'code' => 'love_02',
        'image_url' => 'uploads/images/Strawberry.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Agape love - the fruit of the Spirit. Love is patient, love is kind.',
    ],
    [
        'name' => 'Love',
        'emoji_char' => '❤️',
        'code' => 'love_03',
        'image_url' => 'uploads/images/Strawberry.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Agape love - the fruit of the Spirit. Love is patient, love is kind.',
    ],
    // Joy - Pineapple (3 variants)
    [
        'name' => 'Joy',
        'emoji_char' => '😊',
        'code' => 'joy_01',
        'image_url' => 'uploads/fruitofspirit/pineapple-01.png',
        'category' => 'Fruit of Spirit',
        'description' => 'The joy of the Lord is your strength. True joy comes from serving God.',
    ],
    [
        'name' => 'Joy',
        'emoji_char' => '😊',
        'code' => 'joy_02',
        'image_url' => 'uploads/fruitofspirit/pineapple-02.png',
        'category' => 'Fruit of Spirit',
        'description' => 'The joy of the Lord is your strength. True joy comes from serving God.',
    ],
    [
        'name' => 'Joy',
        'emoji_char' => '😊',
        'code' => 'joy_03',
        'image_url' => 'uploads/fruitofspirit/pineapple-03.png',
        'category' => 'Fruit of Spirit',
        'description' => 'The joy of the Lord is your strength. True joy comes from serving God.',
    ],
    // Peace - Watermelon (3 variants)
    [
        'name' => 'Peace',
        'emoji_char' => '☮️',
        'code' => 'peace_01',
        'image_url' => 'uploads/fruitofspirit/watermelon-01.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Peace with God, Peace of God, Peace on Earth. The peace that transcends understanding.',
    ],
    [
        'name' => 'Peace',
        'emoji_char' => '☮️',
        'code' => 'peace_02',
        'image_url' => 'uploads/fruitofspirit/watermelon-02.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Peace with God, Peace of God, Peace on Earth. The peace that transcends understanding.',
    ],
    [
        'name' => 'Peace',
        'emoji_char' => '☮️',
        'code' => 'peace_03',
        'image_url' => 'uploads/fruitofspirit/watermelon-03.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Peace with God, Peace of God, Peace on Earth. The peace that transcends understanding.',
    ],
    // Patience - Banana (3 variants) - Corrected from pa-01 to banana-01
    [
        'name' => 'Patience',
        'emoji_char' => '⏳',
        'code' => 'patience_01',
        'image_url' => 'uploads/fruitofspirit/banana-01.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Longsuffering - bearing trials with a calm and unruffled temper.',
    ],
    [
        'name' => 'Patience',
        'emoji_char' => '⏳',
        'code' => 'patience_02',
        'image_url' => 'uploads/fruitofspirit/banana-02.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Longsuffering - bearing trials with a calm and unruffled temper.',
    ],
    [
        'name' => 'Patience',
        'emoji_char' => '⏳',
        'code' => 'patience_03',
        'image_url' => 'uploads/fruitofspirit/banana-03.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Longsuffering - bearing trials with a calm and unruffled temper.',
    ],
    // Kindness - Orange (3 variants)
    [
        'name' => 'Kindness',
        'emoji_char' => '🤗',
        'code' => 'kindness_01',
        'image_url' => 'uploads/fruitofspirit/Orange-01.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Showing kindness, gentleness, and compassion to others.',
    ],
    [
        'name' => 'Kindness',
        'emoji_char' => '🤗',
        'code' => 'kindness_02',
        'image_url' => 'uploads/fruitofspirit/Orange-02.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Showing kindness, gentleness, and compassion to others.',
    ],
    [
        'name' => 'Kindness',
        'emoji_char' => '🤗',
        'code' => 'kindness_03',
        'image_url' => 'uploads/fruitofspirit/Orange-03.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Showing kindness, gentleness, and compassion to others.',
    ],
    // Goodness - Kiwi (3 variants) - using ad-01, 02, 03 (assuming ad = kiwi)
    [
        'name' => 'Goodness',
        'emoji_char' => '✨',
        'code' => 'goodness_01',
        'image_url' => 'uploads/fruitofspirit/ad-01.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Moral excellence, virtue, and doing what is right.',
    ],
    [
        'name' => 'Goodness',
        'emoji_char' => '✨',
        'code' => 'goodness_02',
        'image_url' => 'uploads/fruitofspirit/ad-02.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Moral excellence, virtue, and doing what is right.',
    ],
    [
        'name' => 'Goodness',
        'emoji_char' => '✨',
        'code' => 'goodness_03',
        'image_url' => 'uploads/fruitofspirit/ad-03.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Moral excellence, virtue, and doing what is right.',
    ],
    // Faithfulness - Cherry (3 variants)
    // Note: We don't have cherry images, using banana as fallback
    // If cherry images are added, update these URLs
    [
        'name' => 'Faithfulness',
        'emoji_char' => '🙏',
        'code' => 'faithfulness_01',
        'image_url' => 'uploads/fruitofspirit/banana-01.png', // TODO: Replace with cherry-01.png when available
        'category' => 'Fruit of Spirit',
        'description' => 'Firm adherence to truth and duties. Great is thy faithfulness.',
    ],
    [
        'name' => 'Faithfulness',
        'emoji_char' => '🙏',
        'code' => 'faithfulness_02',
        'image_url' => 'uploads/fruitofspirit/banana-02.png', // TODO: Replace with cherry-02.png when available
        'category' => 'Fruit of Spirit',
        'description' => 'Firm adherence to truth and duties. Great is thy faithfulness.',
    ],
    [
        'name' => 'Faithfulness',
        'emoji_char' => '🙏',
        'code' => 'faithfulness_03',
        'image_url' => 'uploads/fruitofspirit/banana-03.png', // TODO: Replace with cherry-03.png when available
        'category' => 'Fruit of Spirit',
        'description' => 'Firm adherence to truth and duties. Great is thy faithfulness.',
    ],
    // Meekness/Gentleness - Grapes (3 variants)
    [
        'name' => 'Meekness',
        'emoji_char' => '🕊️',
        'code' => 'meekness_01',
        'image_url' => 'uploads/fruitofspirit/Graps -01.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Freedom from pride and arrogance. The meek will inherit the earth.',
    ],
    [
        'name' => 'Meekness',
        'emoji_char' => '🕊️',
        'code' => 'meekness_02',
        'image_url' => 'uploads/fruitofspirit/Graps -02.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Freedom from pride and arrogance. The meek will inherit the earth.',
    ],
    [
        'name' => 'Meekness',
        'emoji_char' => '🕊️',
        'code' => 'meekness_03',
        'image_url' => 'uploads/fruitofspirit/Graps -03.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Freedom from pride and arrogance. The meek will inherit the earth.',
    ],
    // Also add Gentleness as alias for Meekness
    [
        'name' => 'Gentleness',
        'emoji_char' => '🕊️',
        'code' => 'gentleness_01',
        'image_url' => 'uploads/fruitofspirit/Graps -01.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Freedom from pride and arrogance. The meek will inherit the earth.',
    ],
    [
        'name' => 'Gentleness',
        'emoji_char' => '🕊️',
        'code' => 'gentleness_02',
        'image_url' => 'uploads/fruitofspirit/Graps -02.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Freedom from pride and arrogance. The meek will inherit the earth.',
    ],
    [
        'name' => 'Gentleness',
        'emoji_char' => '🕊️',
        'code' => 'gentleness_03',
        'image_url' => 'uploads/fruitofspirit/Graps -03.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Freedom from pride and arrogance. The meek will inherit the earth.',
    ],
    // Self-Control - Apple (3 variants)
    [
        'name' => 'Self-Control',
        'emoji_char' => '🎯',
        'code' => 'self_control_01',
        'image_url' => 'uploads/fruitofspirit/Green-apple-01.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Temperance - self-mastery over spirit, soul and body. Not my will, but yours be done.',
    ],
    [
        'name' => 'Self-Control',
        'emoji_char' => '🎯',
        'code' => 'self_control_02',
        'image_url' => 'uploads/fruitofspirit/Green-apple-02.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Temperance - self-mastery over spirit, soul and body. Not my will, but yours be done.',
    ],
    [
        'name' => 'Self-Control',
        'emoji_char' => '🎯',
        'code' => 'self_control_03',
        'image_url' => 'uploads/fruitofspirit/Green-apple-03.png',
        'category' => 'Fruit of Spirit',
        'description' => 'Temperance - self-mastery over spirit, soul and body. Not my will, but yours be done.',
    ],
    
    // ============================================
    // OPPOSITES OF FRUITS (As per Requirements)
    // "Opposites" of fruits also covered (e.g., "Feeling unloved")
    // Using different variants (02, 03) to distinguish from main fruits (01)
    // ============================================
    
    // Love → Lacking Love / Feeling Unloved
    // Note: Strawberry not in fruitofspirit folder, using Orange-02 as alternative
    [
        'name' => 'Lacking Love',
        'emoji_char' => '💔',
        'code' => 'lacking_love',
        'image_url' => 'uploads/fruitofspirit/Orange-02.png', // Different variant for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Feeling unloved or lacking love. Remember, God\'s love is always available.',
    ],
    [
        'name' => 'Feeling Unloved',
        'emoji_char' => '💔',
        'code' => 'feeling_unloved',
        'image_url' => 'uploads/fruitofspirit/Orange-03.png', // Different variant
        'category' => 'Opposite Emotion',
        'description' => 'Feeling unloved. You are loved by God.',
    ],
    
    // Joy → Lacking Joy / Sadness
    [
        'name' => 'Lacking Joy',
        'emoji_char' => '😢',
        'code' => 'lacking_joy',
        'image_url' => 'uploads/fruitofspirit/pineapple-02.png', // Variant 02 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Feeling sad or lacking joy. The joy of the Lord is your strength.',
    ],
    [
        'name' => 'Sadness',
        'emoji_char' => '😢',
        'code' => 'sadness',
        'image_url' => 'uploads/fruitofspirit/pineapple-03.png', // Variant 03 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Feeling sad. God is near to the brokenhearted.',
    ],
    
    // Peace → Struggling with Peace / Anxiety
    [
        'name' => 'Struggling with Peace',
        'emoji_char' => '😰',
        'code' => 'struggling_peace',
        'image_url' => 'uploads/fruitofspirit/watermelon-02.png', // Variant 02 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Struggling with peace or feeling anxious. Cast your cares on Him.',
    ],
    [
        'name' => 'Anxiety',
        'emoji_char' => '😰',
        'code' => 'anxiety',
        'image_url' => 'uploads/fruitofspirit/watermelon-03.png', // Variant 03 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Feeling anxious. God\'s peace transcends understanding.',
    ],
    
    // Patience → Impatient / Restless
    [
        'name' => 'Impatient',
        'emoji_char' => '⏰',
        'code' => 'impatient',
        'image_url' => 'uploads/fruitofspirit/banana-02.png', // Variant 02 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Feeling impatient or restless. Wait on the Lord.',
    ],
    [
        'name' => 'Restless',
        'emoji_char' => '⏰',
        'code' => 'restless',
        'image_url' => 'uploads/fruitofspirit/banana-03.png', // Variant 03 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Feeling restless. Be still and know that He is God.',
    ],
    [
        'name' => 'Impatient',
        'emoji_char' => '⏰',
        'code' => 'impatient_pa',
        'image_url' => 'uploads/fruitofspirit/pa-02.png', // Using pa (patience abbreviation) variant
        'category' => 'Opposite Emotion',
        'description' => 'Feeling impatient. Patience is a virtue.',
    ],
    
    // Kindness → Unkind / Harsh
    [
        'name' => 'Unkind',
        'emoji_char' => '😠',
        'code' => 'unkind',
        'image_url' => 'uploads/fruitofspirit/Orange-02.png', // Variant 02 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Struggling with unkindness. Choose kindness, for it is a fruit of the Spirit.',
    ],
    [
        'name' => 'Harsh',
        'emoji_char' => '😠',
        'code' => 'harsh',
        'image_url' => 'uploads/fruitofspirit/Orange-03.png', // Variant 03 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Feeling harsh. Let your words be seasoned with grace.',
    ],
    
    // Goodness → Lacking Goodness
    [
        'name' => 'Lacking Goodness',
        'emoji_char' => '😔',
        'code' => 'lacking_goodness',
        'image_url' => 'uploads/fruitofspirit/ad-02.png', // Variant 02 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Struggling with goodness. God\'s goodness leads to repentance.',
    ],
    [
        'name' => 'Lacking Goodness',
        'emoji_char' => '😔',
        'code' => 'lacking_goodness_03',
        'image_url' => 'uploads/fruitofspirit/ad-03.png', // Variant 03
        'category' => 'Opposite Emotion',
        'description' => 'Struggling with goodness. Seek God\'s goodness.',
    ],
    
    // Faithfulness → Unfaithful / Doubt
    [
        'name' => 'Unfaithful',
        'emoji_char' => '🤔',
        'code' => 'unfaithful',
        'image_url' => 'uploads/fruitofspirit/banana-02.png', // Variant 02 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Struggling with faithfulness or doubt. God is faithful even when we are not.',
    ],
    [
        'name' => 'Doubt',
        'emoji_char' => '🤔',
        'code' => 'doubt',
        'image_url' => 'uploads/fruitofspirit/banana-03.png', // Variant 03 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Feeling doubt. Help my unbelief, Lord.',
    ],
    
    // Gentleness/Meekness → Proud / Arrogant
    [
        'name' => 'Proud',
        'emoji_char' => '😤',
        'code' => 'proud',
        'image_url' => 'uploads/fruitofspirit/Graps -02.png', // Variant 02 for opposite (note space in filename)
        'category' => 'Opposite Emotion',
        'description' => 'Struggling with pride. God opposes the proud but gives grace to the humble.',
    ],
    [
        'name' => 'Arrogant',
        'emoji_char' => '😤',
        'code' => 'arrogant',
        'image_url' => 'uploads/fruitofspirit/Graps -03.png', // Variant 03 for opposite (note space in filename)
        'category' => 'Opposite Emotion',
        'description' => 'Feeling arrogant. Humility comes before honor.',
    ],
    
    // Self-Control → Lacking Self-Control / Tempted
    [
        'name' => 'Lacking Self-Control',
        'emoji_char' => '😓',
        'code' => 'lacking_self_control',
        'image_url' => 'uploads/fruitofspirit/Green-apple-02.png', // Variant 02 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Struggling with self-control. God provides a way out of temptation.',
    ],
    [
        'name' => 'Tempted',
        'emoji_char' => '😓',
        'code' => 'tempted',
        'image_url' => 'uploads/fruitofspirit/Green-apple-03.png', // Variant 03 for opposite
        'category' => 'Opposite Emotion',
        'description' => 'Feeling tempted. No temptation has overtaken you except what is common to man.',
    ],
    
    // ============================================
    // EMOTION-BASED EMOJIS (As per Requirements)
    // Emojis to express spiritual emotions (e.g. "Thankful," "Grateful")
    // Using different variants (02, 03) to distinguish from main fruits
    // ============================================
    
    // Positive Emotions - Using variants 02 and 03 for variety
    [
        'name' => 'Thankful',
        'emoji_char' => '🙏',
        'code' => 'thankful',
        'image_url' => 'uploads/fruitofspirit/Orange-02.png', // Kindness fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling thankful. Give thanks in all circumstances.',
    ],
    [
        'name' => 'Grateful',
        'emoji_char' => '🙏',
        'code' => 'grateful',
        'image_url' => 'uploads/fruitofspirit/Orange-03.png', // Kindness fruit - variant 03
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling grateful. Gratitude opens the door to more blessings.',
    ],
    [
        'name' => 'Blessed',
        'emoji_char' => '✨',
        'code' => 'blessed',
        'image_url' => 'uploads/fruitofspirit/ad-02.png', // Goodness fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling blessed. Count your blessings, name them one by one.',
    ],
    [
        'name' => 'Blessed',
        'emoji_char' => '✨',
        'code' => 'blessed_03',
        'image_url' => 'uploads/fruitofspirit/ad-03.png', // Goodness fruit - variant 03
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling blessed. God\'s blessings are abundant.',
    ],
    [
        'name' => 'Hopeful',
        'emoji_char' => '🌟',
        'code' => 'hopeful',
        'image_url' => 'uploads/fruitofspirit/Green-apple-02.png', // Self-Control fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling hopeful. Hope does not disappoint.',
    ],
    [
        'name' => 'Hopeful',
        'emoji_char' => '🌟',
        'code' => 'hopeful_03',
        'image_url' => 'uploads/fruitofspirit/Green-apple-03.png', // Self-Control fruit - variant 03
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling hopeful. Our hope is in the Lord.',
    ],
    [
        'name' => 'Praying',
        'emoji_char' => '🙏',
        'code' => 'praying',
        'image_url' => 'uploads/fruitofspirit/banana-02.png', // Faithfulness fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'In prayer. The prayer of a righteous person is powerful and effective.',
    ],
    [
        'name' => 'Praying',
        'emoji_char' => '🙏',
        'code' => 'praying_03',
        'image_url' => 'uploads/fruitofspirit/banana-03.png', // Faithfulness fruit - variant 03
        'category' => 'Spiritual Emotion',
        'description' => 'In prayer. Pray without ceasing.',
    ],
    [
        'name' => 'Worshiping',
        'emoji_char' => '🙌',
        'code' => 'worshiping',
        'image_url' => 'uploads/fruitofspirit/pineapple-02.png', // Joy fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Worshiping God. True worshipers worship in spirit and truth.',
    ],
    [
        'name' => 'Worshiping',
        'emoji_char' => '🙌',
        'code' => 'worshiping_03',
        'image_url' => 'uploads/fruitofspirit/pineapple-03.png', // Joy fruit - variant 03
        'category' => 'Spiritual Emotion',
        'description' => 'Worshiping God. Worship the Lord in the beauty of holiness.',
    ],
    [
        'name' => 'Encouraged',
        'emoji_char' => '💪',
        'code' => 'encouraged',
        'image_url' => 'uploads/fruitofspirit/pineapple-02.png', // Joy fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling encouraged. Encourage one another and build each other up.',
    ],
    [
        'name' => 'Encouraged',
        'emoji_char' => '💪',
        'code' => 'encouraged_03',
        'image_url' => 'uploads/fruitofspirit/pineapple-03.png', // Joy fruit - variant 03
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling encouraged. Be strong and courageous.',
    ],
    [
        'name' => 'Peaceful',
        'emoji_char' => '☮️',
        'code' => 'peaceful',
        'image_url' => 'uploads/fruitofspirit/watermelon-02.png', // Peace fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling peaceful. The peace of God guards your heart and mind.',
    ],
    [
        'name' => 'Peaceful',
        'emoji_char' => '☮️',
        'code' => 'peaceful_03',
        'image_url' => 'uploads/fruitofspirit/watermelon-03.png', // Peace fruit - variant 03
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling peaceful. Peace I leave with you, my peace I give to you.',
    ],
    [
        'name' => 'Loved',
        'emoji_char' => '❤️',
        'code' => 'loved',
        'image_url' => 'uploads/fruitofspirit/Orange-02.png', // Using Orange as Love alternative
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling loved. God\'s love never fails.',
    ],
    [
        'name' => 'Joyful',
        'emoji_char' => '😊',
        'code' => 'joyful',
        'image_url' => 'uploads/fruitofspirit/pineapple-02.png', // Joy fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Feeling joyful. The joy of the Lord is your strength.',
    ],
    [
        'name' => 'Patient',
        'emoji_char' => '⏳',
        'code' => 'patient',
        'image_url' => 'uploads/fruitofspirit/banana-02.png', // Patience fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Being patient. Wait on the Lord, be of good courage.',
    ],
    [
        'name' => 'Kind',
        'emoji_char' => '🤗',
        'code' => 'kind',
        'image_url' => 'uploads/fruitofspirit/Orange-02.png', // Kindness fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Being kind. Kindness is a fruit of the Spirit.',
    ],
    [
        'name' => 'Good',
        'emoji_char' => '✨',
        'code' => 'good',
        'image_url' => 'uploads/fruitofspirit/ad-02.png', // Goodness fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Being good. God is good, all the time.',
    ],
    [
        'name' => 'Faithful',
        'emoji_char' => '🙏',
        'code' => 'faithful',
        'image_url' => 'uploads/fruitofspirit/banana-02.png', // Faithfulness fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Being faithful. God is faithful to His promises.',
    ],
    [
        'name' => 'Gentle',
        'emoji_char' => '🕊️',
        'code' => 'gentle',
        'image_url' => 'uploads/fruitofspirit/Graps -02.png', // Gentleness fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Being gentle. The meek shall inherit the earth.',
    ],
    [
        'name' => 'Self-Controlled',
        'emoji_char' => '🎯',
        'code' => 'self_controlled',
        'image_url' => 'uploads/fruitofspirit/Green-apple-02.png', // Self-Control fruit - variant 02
        'category' => 'Spiritual Emotion',
        'description' => 'Being self-controlled. Self-control is a fruit of the Spirit.',
    ],
];

$results = [];
$added = 0;
$updated = 0;
$errors = 0;

foreach ($fruitEmojis as $emoji) {
    try {
        // Check if emoji already exists (by code or name)
        $checkStmt = $conn->prepare("SELECT id, image_url FROM emojis WHERE code = ? OR name = ?");
        $checkStmt->bind_param("ss", $emoji['code'], $emoji['name']);
        $checkStmt->execute();
        $result = $checkStmt->get_result();
        
        if ($result->num_rows > 0) {
            // Update existing emoji
            $existing = $result->fetch_assoc();
            $updateStmt = $conn->prepare("UPDATE emojis SET 
                name = ?, 
                emoji_char = ?, 
                image_url = ?, 
                description = ?, 
                category = ?,
                status = 'Active'
                WHERE id = ?");
            $updateStmt->bind_param(
                "sssssi",
                $emoji['name'],
                $emoji['emoji_char'],
                $emoji['image_url'],
                $emoji['description'],
                $emoji['category'],
                $existing['id']
            );
            
            if ($updateStmt->execute()) {
                $updated++;
                $results[] = [
                    'action' => 'updated',
                    'name' => $emoji['name'],
                    'id' => $existing['id'],
                    'image_url' => $emoji['image_url']
                ];
            } else {
                $errors++;
                $results[] = [
                    'action' => 'error',
                    'name' => $emoji['name'],
                    'error' => $updateStmt->error
                ];
            }
        } else {
            // Insert new emoji
            $insertStmt = $conn->prepare("INSERT INTO emojis 
                (name, emoji_char, code, image_url, description, category, status, usage_count) 
                VALUES (?, ?, ?, ?, ?, ?, 'Active', 0)");
            $insertStmt->bind_param(
                "ssssss",
                $emoji['name'],
                $emoji['emoji_char'],
                $emoji['code'],
                $emoji['image_url'],
                $emoji['description'],
                $emoji['category']
            );
            
            if ($insertStmt->execute()) {
                $added++;
                $results[] = [
                    'action' => 'added',
                    'name' => $emoji['name'],
                    'id' => $insertStmt->insert_id,
                    'image_url' => $emoji['image_url']
                ];
            } else {
                $errors++;
                $results[] = [
                    'action' => 'error',
                    'name' => $emoji['name'],
                    'error' => $insertStmt->error
                ];
            }
        }
    } catch (Exception $e) {
        $errors++;
        $results[] = [
            'action' => 'error',
            'name' => $emoji['name'],
            'error' => $e->getMessage()
        ];
    }
}

echo json_encode([
    'success' => true,
    'message' => "Processed " . count($fruitEmojis) . " emojis",
    'summary' => [
        'added' => $added,
        'updated' => $updated,
        'errors' => $errors,
        'total' => count($fruitEmojis)
    ],
    'results' => $results
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

$conn->close();
?>

