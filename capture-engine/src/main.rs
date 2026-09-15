use ffmpeg_next::software::scaling::{context::Context as ScaleContext, flag::Flags};
use ffmpeg_next::util::error::EAGAIN;
use ffmpeg_next::{self as ffmpeg, codec::Context, frame::Video};
use scrap::{Capturer, Display};
use std::io::Write;
use std::net::TcpListener;

fn main() {
    ffmpeg::init().expect("ffmpeg not initialized");
    println!("ffmpeg initialized successfully");

    let codec = ffmpeg::encoder::find_by_name("h264_nvenc");

    match codec {
        Some(c) => {
            println!("Found codec: {}", c.name());

            let display = Display::primary().expect("Failed to get primary display");
            let width = display.width();
            let height = display.height();
            println!("Display dimensions: {}x{}", width, height);

            let mut capturer = Capturer::new(display).expect("Failed to create capturer");

            let context = Context::new_with_codec(c);
            let mut builder = context.encoder().video().expect("encoder create err");

            builder.set_width(width as u32);
            builder.set_height(height as u32);
            builder.set_format(ffmpeg::format::Pixel::YUV420P);
            builder.set_time_base(ffmpeg::Rational(1, 30));

            let mut encoder = builder.open().expect("Failed to open encoder");
            println!("Encoder opened!");

            let mut input_frame =
                Video::new(ffmpeg::format::Pixel::BGRA, width as u32, height as u32);
            let mut output_frame =
                Video::new(ffmpeg::format::Pixel::YUV420P, width as u32, height as u32);

            let mut scaler = ScaleContext::get(
                ffmpeg::format::Pixel::BGRA, width as u32, height as u32,
                ffmpeg::format::Pixel::YUV420P, width as u32, height as u32,
                Flags::BILINEAR,
            ).expect("Failed to create scaler");

            println!("⏳ Media server listening on 127.0.0.1:9000 ...");
            let listener = TcpListener::bind("127.0.0.1:9000").expect("bind failed");

            'connections: loop {
                let (mut stream, addr) = listener.accept().expect("accept failed");
                println!("✅ Client connected: {:?}", addr);

                let mut frame_num: i64 = 0;

                loop {
                    let frame_data = match capturer.frame() {
                        Ok(data) => data,
                        Err(_) => continue,
                    };

                    {
                        let input_data = input_frame.data_mut(0);
                        let len = std::cmp::min(input_data.len(), frame_data.len());
                        input_data[..len].copy_from_slice(&frame_data);
                    }

                    if scaler.run(&input_frame, &mut output_frame).is_err() {
                        continue;
                    }

                    output_frame.set_pts(Some(frame_num));

                    if encoder.send_frame(&output_frame).is_err() {
                        continue;
                    }

                    loop {
                        let mut packet = ffmpeg::Packet::empty();
                        match encoder.receive_packet(&mut packet) {
                            Ok(()) => {
                                if let Some(data) = packet.data() {
                                    let len = (data.len() as u32).to_be_bytes();
                                    if stream.write_all(&len).is_err() || stream.write_all(data).is_err() {
                                        println!("❌ Client disconnected");
                                        continue 'connections;
                                    }
                                }
                            }
                            Err(e) if e == ffmpeg::Error::Other { errno: EAGAIN } => break,
                            Err(_) => continue 'connections,
                        }
                    }

                    std::thread::sleep(std::time::Duration::from_millis(33));
                    frame_num += 1;
                }
            }
        }
        None => println!("not found"),
    }
}