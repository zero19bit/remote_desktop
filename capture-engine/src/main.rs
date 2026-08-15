
//use std::time::{Duration, Instant};
use ffmpeg_next::software::scaling::{context::Context as ScaleContext, flag::Flags};
use ffmpeg_next::{self as ffmpeg, codec::Context, frame::Video}; //encoder
use scrap::{Capturer, Display};
//use std::fs::File;

fn main() {
    ffmpeg::init().expect("ffmpeg not initialized");

    println!("ffmpeg initialized successfully");
    // println!("ffmpeg version: {}", ffmpeg::version());


    let codec = ffmpeg::encoder::find_by_name("h264_nvenc");

    match codec {
        Some(c) => {
            println!("Found codec: {}", c.name());
            let display = Display::primary().expect("Failed to get primary display");
            let width = display.width();
            let height = display.height();
            println!("Display dimensions: {}x{}", width, height);

            let mut capturer = Capturer::new(display).expect("Failed to create capturer");
            let mut context = Context::new_with_codec(c);
            println!("Context created!");

            let mut encoder = context.encoder().video().expect("encoder crate err");
            println!("Encoder created!");

            encoder.set_width(width as u32);
            encoder.set_height(height as u32);
            encoder.set_format(ffmpeg::format::Pixel::YUV420P);
            encoder.set_time_base(ffmpeg::Rational(1, 30)); // Set time base to 30 fps

            let mut frame_data = capturer.frame().expect("Failed to capture frame");
            let mut input_frame = Video::new(
                ffmpeg::format::Pixel::BGRA,
                width as u32,
                height as u32,
            );

            {
                let input_data = input_frame.data_mut(0);
                let len = std::cmp::min(input_data.len(), frame_data.len());
                input_data[..len].copy_from_slice(&frame_data);
            }
            
            println!("Frame converted to FFmpeg format!");
            println!("Input frame size: {}x{}", input_frame.width(), input_frame.height());
        },
        None => println!("not found"),
    }
}
