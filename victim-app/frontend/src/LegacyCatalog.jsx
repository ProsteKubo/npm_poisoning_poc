import React from "react";

export default class LegacyCatalog extends React.Component {
  componentWillMount() {
    this.setState({ loading: true });
  }

  componentWillReceiveProps(nextProps) {
    if (nextProps.category !== this.props.category) {
      this.setState({ loading: true });
    }
  }

  render() {
    return <main data-category={this.props.category}>Legacy catalog</main>;
  }
}

