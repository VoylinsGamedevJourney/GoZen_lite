#pragma once

#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

extern "C" {
	#include <libavcodec/avcodec.h>
	#include <libavformat/avformat.h>
	#include <libavdevice/avdevice.h>
	#include <libavutil/dict.h>
	#include <libavutil/channel_layout.h>
	#include <libavutil/opt.h>
	#include <libavutil/imgutils.h>
	#include <libavutil/pixdesc.h>
	#include <libswscale/swscale.h>
	#include <libswresample/swresample.h>
}


using namespace godot;


class Video : public Resource {
	GDCLASS(Video, Resource);

private:

	AVFormatContext* av_format_ctx = nullptr;
	AVStream* av_stream_video = nullptr,* av_stream_audio = nullptr;
	AVCodecContext* av_codec_ctx_video = nullptr,* av_codec_ctx_audio = nullptr;

	AVFrame* av_frame = nullptr;
	AVPacket* av_packet = nullptr;

	struct SwrContext* swr_ctx = nullptr;

	PackedByteArray byte_array;

	int response = 0;

public:

	Video() {}
	~Video() { close_video(); }


	void open_video(String a_path);
	void close_video();

	void print_av_error(const char* a_message);

	Ref<AudioStreamWAV> get_audio();


protected:

	bool is_open = false;


	static inline void _bind_methods() {
		ClassDB::bind_method(D_METHOD("open_video", "a_path"),	&Video::open_video);
		ClassDB::bind_method(D_METHOD("close_video"),	&Video::close_video);

		ClassDB::bind_method(D_METHOD("get_audio"),	&Video::get_audio);
	}

};