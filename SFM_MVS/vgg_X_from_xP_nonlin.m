function X = vgg_X_from_xP_nonlin(u,P,imsize,X)
% VGG_X_FROM_XP_NONLIN - Nonlinear triangulation of 3D point from image points
%
% Usage: X = vgg_X_from_xP_nonlin(u,P,imsize,X)
%
% Inputs:
%   u - 2xK matrix of image points (u,v) for K cameras
%   P - 3x4xK matrix of projection matrices for K cameras
%   imsize - 2xK matrix of image sizes (width,height) for K cameras
%   X - 3x1 initial estimate of the 3D point
%
% Outputs:
%   X - 4x1 triangulated 3D point in homogenous coordinates

% If P is a cell array, concatenate it into a single 3D matrix
if iscell(P)
  P = cat(3,P{:});
end

% Get the number of cameras (K)
K = size(P,3);

% Check if there are enough cameras for 3D reconstruction
if K < 2
  error('Cannot reconstruct 3D from 1 image');
end

% If only u and P are provided, use the linear triangulation method
if nargin==3
  X = vgg_X_from_xP_lin(u,P,imsize);
end

% If only u and P are provided, use the linear triangulation method
if nargin==2
  X = vgg_X_from_xP_lin(u,P);
end

% Precondition the projection matrices and image points
if nargin>2
  for k = 1:K
    % Construct the normalization matrix H for the k-th image
    H = [2/imsize(1,k) 0 -1
         0 2/imsize(2,k) -1
         0 0              1];
    % Normalize the projection matrix and image points
    P(:,:,k) = H*P(:,:,k);
    u(:,k) = H(1:2,1:2)*u(:,k) + H(1:2,3);
  end
end

% Parametrize X such that X = T*[Y;1]; thus x = P*T*[Y;1] = Q*[Y;1]
% Perform SVD on the transpose of X to get the matrix T
[~,~,T] = svd(X',0);
% Reorder the columns of T to ensure the last column is [0;0;1]
T = T(:,[2:end 1]);
% Compute the new projection matrices Q for each camera
for k = 1:K
  Q(:,:,k) = P(:,:,k)*T;
end

% Newton's method for non-linear optimization
Y = [0;0;0]; % Initial guess for the 3D point Y
eprev = inf; % Initialize previous error to infinity
lambda = 1e-5; % Regularization parameter

for n = 1:10
  % Compute the residual and the Jacobian matrix
  [e,J] = resid(Y,u,Q);
  % Check for convergence: if the relative change in error is small, stop
  if 1-norm(e)/norm(eprev) < 1000*eps
    break
  end
  eprev = e; % Update previous error
  % Update the estimate of Y using Tikhonov regularization
  JTJ = J' * J;
  dY = (JTJ + lambda * eye(size(JTJ))) \ (J' * e);
  Y = Y - dY;
end

% Compute the final 3D point X in homogenous coordinates
X = T*[Y;1];

return

%%%%%%%%%%%%%%%%%%%%%%%%%%

function [e,J] = resid(Y,u,Q)
% RESID - Compute the residual and Jacobian for Newton's method
%
% Usage: [e,J] = resid(Y,u,Q)
%
% Inputs:
%   Y - 3x1 current estimate of the 3D point
%   u - 2xK matrix of image points (u,v) for K cameras
%   Q - 4x3xK matrix of normalized projection matrices for K cameras
%
% Outputs:
%   e - 2xK matrix of residuals (u-v) for each camera
%   J - 2x3xK matrix of Jacobians for each camera

% Get the number of cameras (K)
K = size(Q,3);

% Initialize the residuals and Jacobians
e = [];
J = [];

% Loop over all cameras
for k = 1:K
  % Extract the k-th projection matrix components
  q = Q(:,1:3,k);
  x0 = Q(:,4,k);
 % Compute the projected point x in image space for the k-th camera
 x = q*Y + x0;
 % Compute the residual for the k-th camera: the difference between the observed and projected image points
 e = [e; x(1:2)./x(3) - u(:,k)];
 % Compute the Jacobian for the k-th camera
 J = [J; [(x(3)*q(1,:) - x(1)*q(3,:)) ./ (x(3).^2)
        (x(3)*q(2,:) - x(2)*q(3,:)) ./ (x(3).^2)]];
end

% The outputs e and J are the concatenated residuals and Jacobians for all cameras
return
