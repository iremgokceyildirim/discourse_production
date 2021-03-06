class UserActionsController < ApplicationController

  def index
    params.require(:username)
    params.permit(:filter, :offset)

    per_chunk = 30

    user = fetch_user_from_params(include_inactive: current_user.try(:staff?))

    opts = { user_id: user.id,
             user: user,
             offset: params[:offset].to_i,
             limit: per_chunk,
             action_types: (params[:filter] || "").split(",").map(&:to_i),
             guardian: guardian,
             ignore_private_messages: params[:filter] ? false : true }

    # Pending is restricted
    stream = if opts[:action_types].include?(UserAction::PENDING)
      guardian.ensure_can_see_notifications!(user)
      UserAction.stream_queued(opts)
    else
      UserAction.stream(opts)
    end

    stream = stream.to_a
    if stream.length == 0 && (help_key = params['no_results_help_key'])
      if user.id == guardian.user.try(:id)
        help_key += ".self"
      else
        help_key += ".others"
      end
      render json: {
        user_action: [],
        no_results_help: I18n.t(help_key)
      }
    else
      render_serialized(stream, UserActionSerializer, root: 'user_actions')
    end

  end

  def show
    params.require(:id)
    render_serialized(UserAction.stream_item(params[:id], guardian), UserActionSerializer)
  end

  def private_messages
    # DO NOT REMOVE
    # TODO should preload messages to avoid extra http req
  end

end
