%Bonus stage 1 part 2 slider code:
function qam64_constellation_live()
    % Build a fixed 64QAM constellation (Gray 8-PAM per axis)
    Number_symbols = 5e4; k = 6;
    levels8  = [-7 -5 -3 -1 1 3 5 7];
    grayLUT8 = [0 1 3 2 6 7 5 4];
    bits  = randi([0 1], Number_symbols*k, 1);
    b6    = reshape(bits, 6, []).';
    bI    = b6(:,1)*4 + b6(:,2)*2 + b6(:,3);
    bQ    = b6(:,4)*4 + b6(:,5)*2 + b6(:,6);
    gI    = grayLUT8(bI+1).'; gQ = grayLUT8(bQ+1).';
    I     = levels8(gI+1).';   Q  = levels8(gQ+1).';
    s     = I + 1j*Q;
    % Exact Es and Eb
    [Igrid,Qgrid] = meshgrid(levels8, levels8);
    Es  = mean(abs(Igrid(:)+1j*Qgrid(:)).^2); Eb = Es/k;
    % UI
    fig = uifigure('Name','64QAM Constellation vs Eb/N0','Position',[100 100 700 550]);
    ax  = uiaxes(fig, 'Position',[50 100 600 420]); grid(ax,'on'); axis(ax,'equal');
    sld = uislider(fig, 'Position',[80 60 560 3], 'Limits',[0 20], 'Value',10, ...
                   'MajorTicks',0:5:20, 'ValueChangingFcn',@(src,evt) redraw(ax,s,Eb,evt.Value));
    uilabel(fig,'Position',[320 25 100 20],'Text','Eb/N0 (dB)');
    redraw(ax, s, Eb, 10);
end
function redraw(ax, s, Eb, EbN0dB)
    EbN0 = 10^(EbN0dB/10);
    N0   = Eb / EbN0;
    w    = sqrt(N0/2).*(randn(size(s)) + 1j*randn(size(s)));
    r    = s + w;
    Nsnap = min(5e4, numel(s));
    scatter(ax, real(r(1:Nsnap)), imag(r(1:Nsnap)), 6, '.', 'MarkerEdgeAlpha',0.45);
    title(ax, sprintf('64QAM Constellation (Eb/N0 = %.1f dB)', EbN0dB));
    xlabel(ax,'In-phase'); ylabel(ax,'Quadrature');
end