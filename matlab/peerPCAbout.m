tic
svdecon(gpuArray.randn(3000, 'single'));
toc

%%
% load('H:\spont_TX8_2018_03_14')
% load('spont_EMX4_2018_07_24')
%%
statall = stat;

ix = [statall.skew]>.5 & ([statall.npix]<150 & [statall.npix]>20);
sum(ix)

S0 = S(ix,:);

%S0 = S0 - mean(S0,2);
nt0 = 4;
S0 = S0(:, 1:nt0*floor(size(S0,2)/nt0));
S0 = reshape(S0, size(S0,1), nt0, []);
S0 = sq(mean(S0,2));

S0 = S0 - my_conv2(S0,20);

ops.useGPU = 1;

xs = [statall.xglobal];
ys = [statall.yglobal];
xs = xs(ix);
ys = ys(ix);

%%
CC = corrcoef(gpuArray(S0)');
CC = CC  - diag(NaN*diag(CC));
nu = nanstd(CC, 1, 1);
%%
L0 = 0.5;
L1 = 300;
nstd = 4;

[NN, NT] = size(S0);

nsamp = 100;
X  = zeros(nsamp,2);
Ns = zeros(nsamp,2);

rng(20);
for k = 1:nsamp
    i0 = ceil(rand*NN);
    ds = ((xs(i0) - xs).^2 + (ys(i0) - ys).^2).^.5;
    d2 = sign(xs(i0))==sign(xs);
    
    igood = CC(i0, :) < nstd * nu(i0);
    
    iY = find(ds<L0);
    iX = find(ds>L1 & d2 & igood);
    nts = numel(iX);
    
    if 1
        iX = find(~d2 & igood);
        iX = iX(randperm(numel(iX), nts));
    end
    
    Ns(k,:) = [numel(iX) numel(iY)];
    
    Strain = S0(iX, :);
    Stest  = S0(iY, :);
    
    % use this map to predict new neurons
    nt0 = 60 * 3;
    nBatches = ceil(NT/nt0);
    
    ibatch = ceil(linspace(1e-10, nBatches, NT));
    
    Ntrain = ceil(nBatches * 7/10);
    rtrain = randperm(nBatches);
    
    itrain = ismember(ibatch, rtrain(1:Ntrain));
    itest  = ismember(ibatch, rtrain((1+Ntrain):end));
    
    [U Sv V] = svdecon(gpuArray(Strain));
    
    nPC = 100;
    V = U(:, 1:nPC)'*Strain;
    V = V/1000;
    
    lam = 200;
    
    c = (V(:,itrain)*V(:,itrain)' + lam * eye(nPC)) \ (V(:,itrain) * Stest(:, itrain)');
    
    Spred = c' * V;
    
    err = Spred - Stest;
    
    X(k,2) = gather(1 - mean(mean(err(:, itest).^2))/mean(mean(Stest(:, itest).^2)));
    X(k,1) = gather(1 - mean(mean(err(:, itrain).^2))/mean(mean(Stest(:, itrain).^2)));
end

disp(mean(X,1))
disp(mean(Ns,1))

%% de-face
[U Sv V] = svdecon(gpuArray(Strain));

nPC = 200;
V = U(:, 1:nPC)'*Strain;
V = V/1000;

lam = 200;

c = (V(:,itrain)*V(:,itrain)' + lam * eye(nPC)) \ (V(:,itrain) * Stest(:, itrain)');

Spred = c' * V;

err = Spred - Stest;

1 - mean(mean(err(:, itest).^2))/mean(mean(Stest(:, itest).^2))
1 - mean(mean(err(:, itrain).^2))/mean(mean(Stest(:, itest).^2))



