function meta = parse_depth_meta(csvfile)
% PARSE_DEPTH_META  Extract intrinsics/resolution from your funky CSV.
% Returns a struct with fields: W,H,bytesPerPix,Fx,Fy,PPx,PPy,timestamp_ms

txt = fileread(csvfile);
txt = replace(txt, '''','');              % drop single quotes for easier regex

meta.W  = picknum(txt, 'Resolution\s*x,(\d+)');
meta.H  = picknum(txt, 'Resolution\s*y,(\d+)');
meta.bytesPerPix = picknum(txt, 'Bytes\s*per\s*pixel,(\d+)');

meta.Fx = picknum(txt, 'Fx,([0-9.]+)');
meta.Fy = picknum(txt, 'Fy,([0-9.]+)');
meta.PPx = picknum(txt, 'PPx,([0-9.]+)');
meta.PPy = picknum(txt, 'PPy,([0-9.]+)');

% Optional timestamp (ms)
ts = picknum(txt, '\(ms\),([0-9.]+)');
if isempty(ts), ts = NaN; end
meta.timestamp_ms = ts;

% ---- helpers ----
    function v = picknum(s, pat)
        m = regexp(s, pat, 'tokens', 'once');
        if isempty(m), v = []; else, v = str2double(m{1}); end
    end
end
