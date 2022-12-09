(*****************************************************************************

   Liquidsoap, a programmable audio stream generator.
   Copyright 2003-2022 Savonet team

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details, fully stated in the COPYING
   file at the root of the liquidsoap distribution.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

  *****************************************************************************)

(** Decode and read metadata using ffmpeg. *)

exception End_of_file
exception No_stream

let log = Log.make ["decoder"; "ffmpeg"]

module Streams = Map.Make (struct
  type t = int

  let compare = Stdlib.compare
end)

(** Configuration keys for ffmpeg. *)
let mime_types =
  Dtools.Conf.list
    ~p:(Decoder.conf_mime_types#plug "ffmpeg")
    "Mime-types used for decoding with ffmpeg"
    ~d:
      [
        "application/f4v";
        "application/ffmpeg";
        "application/mp4";
        "application/mxf";
        "application/octet-stream";
        "application/octet-stream";
        "application/ogg";
        "application/vnd.pg.format";
        "application/vnd.rn-realmedia";
        "application/vnd.smaf";
        "application/x-mpegURL";
        "application/x-ogg";
        "application/x-pgs";
        "application/x-shockwave-flash";
        "application/x-subrip";
        "application/xml";
        "audio/G722";
        "audio/MP4A-LATM";
        "audio/MPA";
        "audio/aac";
        "audio/aacp";
        "audio/aiff";
        "audio/amr";
        "audio/basic";
        "audio/bit";
        "audio/flac";
        "audio/g723";
        "audio/iLBC";
        "audio/mp4";
        "audio/mpeg";
        "audio/ogg";
        "audio/vnd.wave";
        "audio/wav";
        "audio/wave";
        "audio/webm";
        "audio/x-ac3";
        "audio/x-adpcm";
        "audio/x-caf";
        "audio/x-dca";
        "audio/x-eac3";
        "audio/x-flac";
        "audio/x-gsm";
        "audio/x-hx-aac-adts";
        "audio/x-ogg";
        "audio/x-oma";
        "audio/x-tta";
        "audio/x-voc";
        "audio/x-wav";
        "audio/x-wavpack";
        "multipart/x-mixed-replace;boundary=ffserver";
        "text/vtt";
        "text/x-ass";
        "text/x-jacosub";
        "text/x-microdvd";
        "video/3gpp";
        "video/3gpp2";
        "video/MP2T";
        "video/mp2t";
        "video/mp4";
        "video/mpeg";
        "video/ogg";
        "video/webm";
        "video/x-flv";
        "video/x-h261";
        "video/x-h263";
        "video/x-m4v";
        "video/x-matroska";
        "video/x-mjpeg";
        "video/x-ms-asf";
        "video/x-msvideo";
        "video/x-nut";
      ]

let image_mime_types =
  Dtools.Conf.list ~p:(mime_types#plug "images")
    "Mime-types used for decoding images with ffmpeg"
    ~d:
      [
        "image/gif";
        "image/jpeg";
        "image/png";
        "image/vnd.microsoft.icon";
        "image/webp";
      ]

let file_extensions =
  Dtools.Conf.list
    ~p:(Decoder.conf_file_extensions#plug "ffmpeg")
    "File extensions used for decoding media files (except images) with ffmpeg"
    ~d:
      [
        "264";
        "265";
        "302";
        "3g2";
        "3gp";
        "669";
        "722";
        "A64";
        "a64";
        "aa";
        "aa3";
        "aac";
        "aax";
        "ac3";
        "acm";
        "adf";
        "adp";
        "ads";
        "adts";
        "adx";
        "aea";
        "afc";
        "aif";
        "aifc";
        "aiff";
        "aix";
        "amf";
        "amr";
        "ams";
        "amv";
        "ape";
        "apl";
        "apm";
        "apng";
        "aptx";
        "aptxhd";
        "aqt";
        "asf";
        "ass";
        "ast";
        "au";
        "aud";
        "avi";
        "avr";
        "avs";
        "avs2";
        "bcstm";
        "bfstm";
        "binka";
        "bit";
        "bmv";
        "brstm";
        "c2";
        "caf";
        "cavs";
        "cdata";
        "cdg";
        "cdxl";
        "cgi";
        "chk";
        "cif";
        "cpk";
        "cvg";
        "dat";
        "daud";
        "dav";
        "dbm";
        "dif";
        "digi";
        "dmf";
        "dnxhd";
        "dnxhr";
        "drc";
        "dsm";
        "dss";
        "dtk";
        "dtm";
        "dts";
        "dtshd";
        "dv";
        "dvd";
        "eac3";
        "f4v";
        "fap";
        "far";
        "ffmeta";
        "fits";
        "flac";
        "flm";
        "flv";
        "fsb";
        "fwse";
        "g722";
        "g723_1";
        "g729";
        "gdm";
        "genh";
        "gif";
        "gsm";
        "gxf";
        "h261";
        "h263";
        "h264";
        "h265";
        "hca";
        "hevc";
        "ice";
        "ico";
        "idf";
        "idx";
        "ifv";
        "imf";
        "imx";
        "ipu";
        "ircam";
        "ism";
        "isma";
        "ismv";
        "it";
        "ivf";
        "ivr";
        "j2b";
        "jss";
        "kux";
        "latm";
        "lbc";
        "loas";
        "lrc";
        "lvf";
        "m15";
        "m1v";
        "m2a";
        "m2t";
        "m2ts";
        "m2v";
        "m3u8";
        "m4a";
        "m4b";
        "m4v";
        "mac";
        "mca";
        "mcc";
        "mdl";
        "med";
        "mj2";
        "mjpeg";
        "mjpg";
        "mk3d";
        "mka";
        "mks";
        "mkv";
        "mlp";
        "mmcmp";
        "mmf";
        "mms";
        "mo3";
        "mod";
        "mods";
        "moflex";
        "mov";
        "mp2";
        "mp3";
        "mp4";
        "mpa";
        "mpc";
        "mpd";
        "mpeg";
        "mpg";
        "mpl2";
        "mptm";
        "msbc";
        "msf";
        "mt2";
        "mtaf";
        "mtm";
        "mts";
        "musx";
        "mvi";
        "mxf";
        "mxg";
        "nist";
        "nsp";
        "nst";
        "nut";
        "obu";
        "oga";
        "ogg";
        "ogv";
        "okt";
        "oma";
        "omg";
        "opus";
        "paf";
        "pcm";
        "pjs";
        "plm";
        "psm";
        "psp";
        "pt36";
        "ptm";
        "pvf";
        "qcif";
        "ra";
        "rco";
        "rcv";
        "rgb";
        "rm";
        "roq";
        "rsd";
        "rso";
        "rt";
        "s3m";
        "sami";
        "sbc";
        "sbg";
        "scc";
        "sdr2";
        "sds";
        "sdx";
        "ser";
        "sf";
        "sfx";
        "sfx2";
        "sga";
        "shn";
        "sln";
        "smi";
        "son";
        "sox";
        "spdif";
        "sph";
        "spx";
        "srt";
        "ss2";
        "ssa";
        "st26";
        "stk";
        "stl";
        "stm";
        "stp";
        "str";
        "sub";
        "sup";
        "svag";
        "svs";
        "swf";
        "tak";
        "tco";
        "thd";
        "ts";
        "tta";
        "ttml";
        "tun";
        "txt";
        "ty";
        "ty+";
        "ult";
        "umx";
        "v";
        "v210";
        "vag";
        "vb";
        "vc1";
        "vc2";
        "viv";
        "vob";
        "voc";
        "vpk";
        "vqe";
        "vqf";
        "vql";
        "vtt";
        "w64";
        "wav";
        "webm";
        "wma";
        "wmv";
        "wow";
        "wsd";
        "wtv";
        "wv";
        "xl";
        "xm";
        "xml";
        "xmv";
        "xpk";
        "xvag";
        "y4m";
        "yop";
        "yuv";
      ]

let image_file_extensions =
  Dtools.Conf.list
    ~p:(file_extensions#plug "images")
    "File extensions used for decoding images with ffmpeg"
    ~d:
      [
        "bmp";
        "cri";
        "dds";
        "dng";
        "dpx";
        "exr";
        "im1";
        "im24";
        "im32";
        "im8";
        "j2c";
        "j2k";
        "jls";
        "jp2";
        "jpc";
        "jpeg";
        "jpg";
        "jps";
        "ljpg";
        "mng";
        "mpg1-img";
        "mpg2-img";
        "mpg4-img";
        "mpo";
        "pam";
        "pbm";
        "pcd";
        "pct";
        "pcx";
        "pfm";
        "pgm";
        "pgmyuv";
        "pic";
        "pict";
        "pix";
        "png";
        "pnm";
        "pns";
        "ppm";
        "ptx";
        "ras";
        "raw";
        "rs";
        "sgi";
        "sun";
        "sunras";
        "svg";
        "svgz";
        "tga";
        "tif";
        "tiff";
        "webp";
        "xbm";
        "xface";
        "xpm";
        "xwd";
        "y";
        "yuv10";
      ]

let priority =
  Dtools.Conf.int
    ~p:(Decoder.conf_priorities#plug "ffmpeg")
    "Priority for the ffmpeg decoder" ~d:10

let duration file =
  let container = Av.open_input file in
  Tutils.finalize
    ~k:(fun () -> Av.close container)
    (fun () ->
      let duration = Av.get_input_duration container ~format:`Millisecond in
      Option.map (fun d -> Int64.to_float d /. 1000.) duration)

let () =
  Plug.register Request.dresolvers "ffmepg" ~doc:"" (fun fname ->
      match duration fname with None -> raise Not_found | Some d -> d)

let tags_substitutions = [("track", "tracknumber")]

let get_tags file =
  let container = Av.open_input file in
  Tutils.finalize
    ~k:(fun () -> Av.close container)
    (fun () ->
      (* For now we only add the metadata from the best audio track *)
      let audio_tags =
        try
          let _, s, _ = Av.find_best_audio_stream container in
          Av.get_metadata s
        with _ -> []
      in
      let tags = Av.get_input_metadata container in
      List.map
        (fun (lbl, v) ->
          try (List.assoc lbl tags_substitutions, v) with _ -> (lbl, v))
        (audio_tags @ tags))

let () = Plug.register Request.mresolvers "ffmpeg" ~doc:"" get_tags

(* Get the type of an input container. *)
let get_type ~ctype ~url container =
  let audio_streams, descriptions =
    List.fold_left
      (fun (audio_streams, descriptions) (_, _, params) ->
        try
          let field = Frame.Fields.audio_n (List.length audio_streams) in
          let channels = Avcodec.Audio.get_nb_channels params in
          let samplerate = Avcodec.Audio.get_sample_rate params in
          let codec_name =
            Avcodec.Audio.string_of_id (Avcodec.Audio.get_params_id params)
          in
          let description =
            Printf.sprintf "%s: {codec: %s, %dHz, %d channel(s)}"
              (Frame.Fields.string_of_field field)
              codec_name samplerate channels
          in
          ((field, params) :: audio_streams, description :: descriptions)
        with Avutil.Error _ -> (audio_streams, descriptions))
      ([], [])
      (Av.get_audio_streams container)
  in
  let video_streams, descriptions =
    List.fold_left
      (fun (video_streams, descriptions) (_, _, params) ->
        try
          let field = Frame.Fields.video_n (List.length video_streams) in
          let width = Avcodec.Video.get_width params in
          let height = Avcodec.Video.get_height params in
          let pixel_format =
            match Avcodec.Video.get_pixel_format params with
              | None -> "unknown"
              | Some f -> (
                  match Avutil.Pixel_format.to_string f with
                    | None -> "none"
                    | Some s -> s)
          in
          let codec_name =
            Avcodec.Video.string_of_id (Avcodec.Video.get_params_id params)
          in
          let description =
            Printf.sprintf "%s: {codec: %s, %dx%d, %s}"
              (Frame.Fields.string_of_field field)
              codec_name width height pixel_format
          in
          (video_streams @ [(field, params)], descriptions @ [description])
        with Avutil.Error _ -> (video_streams, descriptions))
      ([], descriptions)
      (Av.get_video_streams container)
  in
  if audio_streams = [] && video_streams = [] then
    failwith "No valid stream found in file.";
  let content_type =
    List.fold_left
      (fun content_type (field, params) ->
        match (params, Frame.Fields.find_opt field ctype) with
          | p, Some format when Ffmpeg_copy_content.is_format format ->
              ignore
                (Content.merge format
                   (Ffmpeg_copy_content.lift_params (Some (`Audio p))));
              Frame.Fields.add field format content_type
          | p, Some format when Ffmpeg_raw_content.Audio.is_format format ->
              ignore
                (Content.merge format
                   Ffmpeg_raw_content.(
                     Audio.lift_params (AudioSpecs.mk_params p)));
              Frame.Fields.add field format content_type
          | p, _ ->
              Frame.Fields.add field
                Content.(
                  Audio.lift_params
                    {
                      Content.channel_layout =
                        lazy
                          (Audio_converter.Channel_layout.layout_of_channels
                             (Avcodec.Audio.get_nb_channels p));
                    })
                content_type)
      Frame.Fields.empty audio_streams
  in
  let content_type =
    List.fold_left
      (fun content_type (field, params) ->
        match (params, Frame.Fields.find_opt field ctype) with
          | p, Some format when Ffmpeg_copy_content.is_format format ->
              ignore
                (Content.merge format
                   (Ffmpeg_copy_content.lift_params (Some (`Video p))));
              Frame.Fields.add field format content_type
          | p, Some format when Ffmpeg_raw_content.Video.is_format format ->
              ignore
                (Content.merge format
                   Ffmpeg_raw_content.(
                     Video.lift_params (VideoSpecs.mk_params p)));
              Frame.Fields.add field format content_type
          | _ ->
              Frame.Fields.add field
                Content.(default_format Video.kind)
                content_type)
      content_type video_streams
  in
  log#info "ffmpeg recognizes %s as: %s and content-type: %s."
    (Lang_string.quote_string url)
    (String.concat ", " (List.rev descriptions))
    (Frame.string_of_content_type content_type);
  content_type

let seek ~target_position ~container ticks =
  let tpos = Frame.seconds_of_main ticks in
  log#debug "Setting target position to %f" tpos;
  target_position := Some tpos;
  let ts = Int64.of_float (tpos *. 1000.) in
  let frame_duration = Lazy.force Frame.duration in
  let min_ts = Int64.of_float ((tpos -. frame_duration) *. 1000.) in
  let max_ts = ts in
  Av.seek ~fmt:`Millisecond ~min_ts ~max_ts ~ts container;
  ticks

let mk_decoder ~streams ~target_position container =
  let check_pts stream pts =
    match (pts, !target_position) with
      | Some pts, Some target_position ->
          let { Avutil.num; den } = Av.get_time_base stream in
          let position = Int64.to_float pts *. float num /. float den in
          target_position <= position
      | _ -> true
  in
  let audio_frame =
    Streams.fold
      (fun _ v cur -> match v with `Audio_frame (s, _) -> s :: cur | _ -> cur)
      streams []
  in
  let audio_packet =
    Streams.fold
      (fun _ v cur ->
        match v with `Audio_packet (s, _) -> s :: cur | _ -> cur)
      streams []
  in
  let video_frame =
    Streams.fold
      (fun _ v cur -> match v with `Video_frame (s, _) -> s :: cur | _ -> cur)
      streams []
  in
  let video_packet =
    Streams.fold
      (fun _ v cur ->
        match v with `Video_packet (s, _) -> s :: cur | _ -> cur)
      streams []
  in
  fun buffer ->
    let rec f () =
      try
        let data =
          Av.read_input ~audio_frame ~audio_packet ~video_frame ~video_packet
            container
        in
        match data with
          | `Audio_frame (i, frame) -> (
              match Streams.find_opt i streams with
                | Some (`Audio_frame (_, decode)) ->
                    if
                      check_pts (List.hd audio_frame)
                        (Ffmpeg_utils.best_pts frame)
                    then decode ~buffer frame
                | _ -> f ())
          | `Audio_packet (i, packet) -> (
              match Streams.find_opt i streams with
                | Some (`Audio_packet (_, decode)) ->
                    if
                      check_pts (List.hd audio_packet)
                        (Avcodec.Packet.get_pts packet)
                    then decode ~buffer packet
                | _ -> f ())
          | `Video_frame (i, frame) -> (
              match Streams.find_opt i streams with
                | Some (`Video_frame (_, decode)) ->
                    if
                      check_pts (List.hd video_frame)
                        (Ffmpeg_utils.best_pts frame)
                    then decode ~buffer frame
                | _ -> f ())
          | `Video_packet (i, packet) -> (
              match Streams.find_opt i streams with
                | Some (`Video_packet (_, decode)) ->
                    if
                      check_pts (List.hd video_packet)
                        (Avcodec.Packet.get_pts packet)
                    then decode ~buffer packet
                | _ -> f ())
          | _ -> ()
      with
        | Avutil.Error `Invalid_data -> f ()
        | Avutil.Error `Eof ->
            Generator.add_track_mark buffer.Decoder.generator;
            raise End_of_file
        | exn ->
            let bt = Printexc.get_raw_backtrace () in
            Generator.add_track_mark buffer.Decoder.generator;
            Printexc.raise_with_backtrace exn bt
    in
    f ()

let mk_streams ~ctype ~decode_first_metadata container =
  let check_metadata stream fn =
    let is_first = ref true in
    let latest_metadata = ref None in
    fun ~buffer data ->
      let m = Av.get_metadata stream in
      if
        ((not !is_first) || decode_first_metadata) && Some m <> !latest_metadata
      then (
        is_first := false;
        latest_metadata := Some m;
        Generator.add_metadata buffer.Decoder.generator
          (Frame.metadata_of_list m));
      fn ~buffer data
  in
  let stream_idx = Ffmpeg_content_base.new_stream_idx () in
  let streams, _ =
    List.fold_left
      (fun (streams, pos) (idx, stream, params) ->
        let field = Frame.Fields.audio_n pos in
        match Frame.Fields.find_opt field ctype with
          | Some format when Ffmpeg_copy_content.is_format format ->
              ( Streams.add idx
                  (`Audio_packet
                    ( stream,
                      check_metadata stream
                        (Ffmpeg_copy_decoder.mk_audio_decoder ~stream_idx
                           ~format ~field ~stream params) ))
                  streams,
                pos + 1 )
          | _ -> (streams, pos + 1))
      (Streams.empty, 0)
      (Av.get_audio_streams container)
  in
  let streams, _ =
    List.fold_left
      (fun (streams, pos) (idx, stream, params) ->
        let field = Frame.Fields.audio_n pos in
        match Frame.Fields.find_opt field ctype with
          | Some format when Ffmpeg_raw_content.Audio.is_format format ->
              ( Streams.add idx
                  (`Audio_frame
                    ( stream,
                      check_metadata stream
                        (Ffmpeg_raw_decoder.mk_audio_decoder ~stream_idx ~format
                           ~stream ~field params) ))
                  streams,
                pos + 1 )
          | Some format when Content.Audio.is_format format ->
              let channels = Content.Audio.channels_of_format format in
              ( Streams.add idx
                  (`Audio_frame
                    ( stream,
                      check_metadata stream
                        (Ffmpeg_internal_decoder.mk_audio_decoder ~channels
                           ~stream ~field params) ))
                  streams,
                pos + 1 )
          | _ -> (streams, pos + 1))
      (streams, 0)
      (Av.get_audio_streams container)
  in
  let streams, _ =
    List.fold_left
      (fun (streams, pos) (idx, stream, params) ->
        let field = Frame.Fields.video_n pos in
        match Frame.Fields.find_opt field ctype with
          | Some format when Ffmpeg_copy_content.is_format format ->
              ( Streams.add idx
                  (`Video_packet
                    ( stream,
                      check_metadata stream
                        (Ffmpeg_copy_decoder.mk_video_decoder ~stream_idx
                           ~format ~field ~stream params) ))
                  streams,
                pos + 1 )
          | _ -> (streams, pos + 1))
      (streams, 0)
      (Av.get_video_streams container)
  in
  let streams, _ =
    List.fold_left
      (fun (streams, pos) (idx, stream, params) ->
        let field = Frame.Fields.video_n pos in
        match Frame.Fields.find_opt field ctype with
          | Some format when Ffmpeg_raw_content.Video.is_format format ->
              ( Streams.add idx
                  (`Video_frame
                    ( stream,
                      check_metadata stream
                        (Ffmpeg_raw_decoder.mk_video_decoder ~stream_idx ~format
                           ~stream ~field params) ))
                  streams,
                pos + 1 )
          | Some format when Content.Video.is_format format ->
              let width, height = Content.Video.dimensions_of_format format in
              ( Streams.add idx
                  (`Video_frame
                    ( stream,
                      check_metadata stream
                        (Ffmpeg_internal_decoder.mk_video_decoder ~width ~height
                           ~stream ~field params) ))
                  streams,
                pos + 1 )
          | _ -> (streams, pos + 1))
      (streams, 0)
      (Av.get_video_streams container)
  in
  streams

let create_decoder ~ctype fname =
  let duration = duration fname in
  let remaining = ref duration in
  let m = Mutex.create () in
  let set_remaining stream pts =
    Tutils.mutexify m
      (fun () ->
        match (duration, pts) with
          | None, _ | Some _, None -> ()
          | Some d, Some pts -> (
              let { Avutil.num; den } = Av.get_time_base stream in
              let position =
                Int64.to_float (Int64.mul (Int64.of_int num) pts) /. float den
              in
              match !remaining with
                | None -> remaining := Some (d -. position)
                | Some r -> remaining := Some (min (d -. position) r)))
      ()
  in
  let get_remaining =
    Tutils.mutexify m (fun () ->
        match !remaining with None -> -1 | Some r -> Frame.main_of_seconds r)
  in
  let opts = Hashtbl.create 10 in
  let ext = Filename.extension fname in
  if List.exists (fun s -> ext = "." ^ s) image_file_extensions#get then (
    Hashtbl.add opts "loop" (`Int 1);
    Hashtbl.add opts "framerate" (`Int (Lazy.force Frame.video_rate)));
  let container = Av.open_input ~opts fname in
  let streams = mk_streams ~ctype ~decode_first_metadata:false container in
  let streams =
    Streams.map
      (function
        | `Audio_packet (stream, decoder) ->
            let decoder ~buffer packet =
              set_remaining stream (Avcodec.Packet.get_pts packet);
              decoder ~buffer packet
            in
            `Audio_packet (stream, decoder)
        | `Audio_frame (stream, decoder) ->
            let decoder ~buffer frame =
              set_remaining stream (Ffmpeg_utils.best_pts frame);
              decoder ~buffer frame
            in
            `Audio_frame (stream, decoder)
        | `Video_packet (stream, decoder) ->
            let decoder ~buffer packet =
              set_remaining stream (Avcodec.Packet.get_pts packet);
              decoder ~buffer packet
            in
            `Video_packet (stream, decoder)
        | `Video_frame (stream, decoder) ->
            let decoder ~buffer frame =
              set_remaining stream (Ffmpeg_utils.best_pts frame);
              decoder ~buffer frame
            in
            `Video_frame (stream, decoder))
      streams
  in
  let close () = Av.close container in
  let target_position = ref None in
  ( {
      Decoder.seek =
        (fun ticks ->
          match duration with
            | None -> -1
            | Some d -> (
                let target =
                  ticks + Frame.main_of_seconds d - get_remaining ()
                in
                match seek ~target_position ~container target with
                  | 0 -> 0
                  | _ -> ticks));
      decode = mk_decoder ~streams ~target_position container;
    },
    close,
    get_remaining )

let create_file_decoder ~metadata:_ ~ctype filename =
  let decoder, close, remaining = create_decoder ~ctype filename in
  Decoder.file_decoder ~filename ~close ~remaining ~ctype decoder

let create_stream_decoder ~ctype mime input =
  let seek_input =
    match input.Decoder.lseek with
      | None -> None
      | Some fn -> Some (fun len _ -> fn len)
  in
  let opts = Hashtbl.create 10 in
  if List.exists (fun s -> mime = s) image_mime_types#get then (
    Hashtbl.add opts "loop" (`Int 1);
    Hashtbl.add opts "framerate" (`Int (Lazy.force Frame.video_rate)));
  let container =
    Av.open_input_stream ?seek:seek_input ~opts input.Decoder.read
  in
  let streams = mk_streams ~ctype ~decode_first_metadata:true container in
  let target_position = ref None in
  {
    Decoder.seek = seek ~target_position ~container;
    decode = mk_decoder ~streams ~target_position container;
  }

let get_file_type ~ctype filename =
  (* If file is an image, leave internal decoding to
     the image decoder. *)
  match
    (Utils.get_ext_opt filename, Frame.Fields.find_opt Frame.Fields.video ctype)
  with
    | Some ext, Some format
      when List.mem ext image_file_extensions#get
           && Content.Video.is_format format ->
        Frame.Fields.make ()
    | _ ->
        let container = Av.open_input filename in
        Tutils.finalize
          ~k:(fun () -> Av.close container)
          (fun () -> get_type ~ctype ~url:filename container)

let () =
  Plug.register Decoder.decoders "ffmpeg"
    ~doc:
      "Use FFmpeg to decode any file or stream if its MIME type or file \
       extension is appropriate."
    {
      Decoder.media_type = `Audio_video;
      priority = (fun () -> priority#get);
      file_extensions =
        (fun () -> Some (file_extensions#get @ image_file_extensions#get));
      mime_types = (fun () -> Some (mime_types#get @ image_mime_types#get));
      file_type = (fun ~ctype filename -> Some (get_file_type ~ctype filename));
      file_decoder = Some create_file_decoder;
      stream_decoder = Some create_stream_decoder;
    }