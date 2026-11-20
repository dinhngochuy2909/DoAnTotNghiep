/// Kho ảnh minh họa cho sân, chia theo môn. Mỗi ảnh đã được xem và chọn đúng môn thể thao.
///
/// Đây là ảnh MINH HỌA lấy từ Pexels và Unsplash (miễn phí, không cần xin phép), KHÔNG phải ảnh thật của từng sân.
/// Chủ sân có thể thay bằng ảnh thật của mình trong màn hình quản lý sân; khi đó ảnh sẽ không còn nhãn "Ảnh minh họa".
class VenuePhotos {
  VenuePhotos._();

  static const Map<String, List<String>> bySport = {
    // Cầu lông: 23 ảnh
    'badminton': [
      'https://images.pexels.com/photos/8007171/pexels-photo-8007171.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007089/pexels-photo-8007089.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007094/pexels-photo-8007094.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/2202685/pexels-photo-2202685.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007499/pexels-photo-8007499.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8496276/pexels-photo-8496276.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5767580/pexels-photo-5767580.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/3660204/pexels-photo-3660204.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007081/pexels-photo-8007081.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007082/pexels-photo-8007082.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007083/pexels-photo-8007083.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007084/pexels-photo-8007084.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007086/pexels-photo-8007086.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007090/pexels-photo-8007090.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007092/pexels-photo-8007092.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007490/pexels-photo-8007490.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007493/pexels-photo-8007493.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007500/pexels-photo-8007500.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8796048/pexels-photo-8796048.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007166/pexels-photo-8007166.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8007491/pexels-photo-8007491.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=800&h=450&fit=crop&q=80',
      'https://images.unsplash.com/photo-1521537634581-0dced2fee2ef?w=800&h=450&fit=crop&q=80',
    ],
    // Pickleball: 18 ảnh
    'pickleball': [
      'https://images.pexels.com/photos/29439335/pexels-photo-29439335.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/29439337/pexels-photo-29439337.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/29439341/pexels-photo-29439341.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/29439334/pexels-photo-29439334.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/29439338/pexels-photo-29439338.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/29439331/pexels-photo-29439331.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/32975180/pexels-photo-32975180.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/32975182/pexels-photo-32975182.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/17299534/pexels-photo-17299534.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/29439333/pexels-photo-29439333.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/17299525/pexels-photo-17299525.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/17299530/pexels-photo-17299530.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/17299533/pexels-photo-17299533.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/29439323/pexels-photo-29439323.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/29439325/pexels-photo-29439325.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/29439343/pexels-photo-29439343.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/29439345/pexels-photo-29439345.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/29439324/pexels-photo-29439324.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
    ],
    // Tennis: 35 ảnh
    'tennis': [
      'https://images.pexels.com/photos/1784798/pexels-photo-1784798.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/17429850/pexels-photo-17429850.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/17945162/pexels-photo-17945162.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/38503139/pexels-photo-38503139.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5740519/pexels-photo-5740519.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5740521/pexels-photo-5740521.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/38413163/pexels-photo-38413163.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/7613507/pexels-photo-7613507.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/9093874/pexels-photo-9093874.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/9716299/pexels-photo-9716299.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13425628/pexels-photo-13425628.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/30760348/pexels-photo-30760348.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/2627310/pexels-photo-2627310.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5739115/pexels-photo-5739115.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5739120/pexels-photo-5739120.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5739121/pexels-photo-5739121.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5740515/pexels-photo-5740515.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5740517/pexels-photo-5740517.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5740522/pexels-photo-5740522.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5740526/pexels-photo-5740526.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5741292/pexels-photo-5741292.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5741294/pexels-photo-5741294.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5741296/pexels-photo-5741296.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5741298/pexels-photo-5741298.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5741299/pexels-photo-5741299.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5741300/pexels-photo-5741300.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5741303/pexels-photo-5741303.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/23249144/pexels-photo-23249144.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/34015718/pexels-photo-34015718.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/34015721/pexels-photo-34015721.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/38503131/pexels-photo-38503131.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/38503136/pexels-photo-38503136.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/38503140/pexels-photo-38503140.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.unsplash.com/photo-1595435934249-5df7ed86e1c0?w=800&h=450&fit=crop&q=80',
      'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=800&h=450&fit=crop&q=80',
    ],
    // Bóng rổ: 29 ảnh
    'basketball': [
      'https://images.pexels.com/photos/1702624/pexels-photo-1702624.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/9739474/pexels-photo-9739474.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/33877382/pexels-photo-33877382.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/11931734/pexels-photo-11931734.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/2529342/pexels-photo-2529342.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/27394936/pexels-photo-27394936.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/4261764/pexels-photo-4261764.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5407033/pexels-photo-5407033.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/7337614/pexels-photo-7337614.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13806273/pexels-photo-13806273.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/7160121/pexels-photo-7160121.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/267761/pexels-photo-267761.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/7201549/pexels-photo-7201549.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/7201554/pexels-photo-7201554.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/7201556/pexels-photo-7201556.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/7337605/pexels-photo-7337605.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/7337611/pexels-photo-7337611.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/7337612/pexels-photo-7337612.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/7337617/pexels-photo-7337617.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/7513413/pexels-photo-7513413.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8337486/pexels-photo-8337486.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/10951853/pexels-photo-10951853.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/12700811/pexels-photo-12700811.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/15048601/pexels-photo-15048601.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/31036780/pexels-photo-31036780.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/31174804/pexels-photo-31174804.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/31671228/pexels-photo-31671228.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.unsplash.com/photo-1519861531473-9200262188bf?w=800&h=450&fit=crop&q=80',
      'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800&h=450&fit=crop&q=80',
    ],
    // Bóng đá: 45 ảnh
    'football': [
      'https://images.pexels.com/photos/33267122/pexels-photo-33267122.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/17300592/pexels-photo-17300592.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/16826134/pexels-photo-16826134.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/19436350/pexels-photo-19436350.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907456/pexels-photo-13907456.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/15781059/pexels-photo-15781059.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/15673781/pexels-photo-15673781.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/11434115/pexels-photo-11434115.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/30651230/pexels-photo-30651230.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/1378425/pexels-photo-1378425.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907425/pexels-photo-13907425.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/399187/pexels-photo-399187.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907433/pexels-photo-13907433.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/11221497/pexels-photo-11221497.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8941650/pexels-photo-8941650.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/1084462/pexels-photo-1084462.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907420/pexels-photo-13907420.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907423/pexels-photo-13907423.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907426/pexels-photo-13907426.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907429/pexels-photo-13907429.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907430/pexels-photo-13907430.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907434/pexels-photo-13907434.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907438/pexels-photo-13907438.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907439/pexels-photo-13907439.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907445/pexels-photo-13907445.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907448/pexels-photo-13907448.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907450/pexels-photo-13907450.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/13907454/pexels-photo-13907454.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/3212317/pexels-photo-3212317.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/3316945/pexels-photo-3316945.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/5470359/pexels-photo-5470359.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/8740433/pexels-photo-8740433.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/9188383/pexels-photo-9188383.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/9739469/pexels-photo-9739469.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/17896212/pexels-photo-17896212.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/17955074/pexels-photo-17955074.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/27307529/pexels-photo-27307529.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/31825803/pexels-photo-31825803.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/33658737/pexels-photo-33658737.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/16602711/pexels-photo-16602711.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/15673779/pexels-photo-15673779.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/15673782/pexels-photo-15673782.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.pexels.com/photos/15673775/pexels-photo-15673775.jpeg?auto=compress&cs=tinysrgb&w=800&h=450&fit=crop',
      'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?w=800&h=450&fit=crop&q=80',
      'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&h=450&fit=crop&q=80',
    ],
  };

  /// Danh sách ảnh của một môn; môn lạ thì dùng ảnh pickleball.
  static List<String> forSport(String type) => bySport[type] ?? bySport['pickleball']!;

  /// Ảnh thứ [rank] của môn [type], xoay vòng. Dùng để chia đều ảnh cho các sân cùng môn.
  static String pick(String type, int rank) {
    final list = forSport(type);
    return list[rank % list.length];
  }

  /// Ảnh mặc định ổn định của một sân (theo id), dùng khi sân chưa có ảnh.
  static String forVenue(String type, int id) => pick(type, id);

  /// Ảnh này có nằm trong kho ảnh minh họa (Pexels/Unsplash) không, tức không phải ảnh thật do chủ sân đăng.
  static bool isStock(String url) {
    final u = url.trim();
    return u.startsWith('https://images.pexels.com/') || u.startsWith('https://images.unsplash.com/');
  }

  /// Bộ ảnh cho tab "Hình ảnh" của một sân: ảnh chính trước, rồi các ảnh khác CÙNG MÔN (không lặp).
  static List<String> gallery(String type, String mainImage, int venueId, {int count = 4}) {
    final list = forSport(type);
    final out = <String>[];
    final main = mainImage.trim();
    if (main.isNotEmpty) out.add(main);
    for (var k = 1; k <= list.length && out.length < count; k++) {
      final url = list[(venueId + k) % list.length];
      if (!out.contains(url)) out.add(url);
    }
    return out;
  }
}
